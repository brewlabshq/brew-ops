#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/anza-xyz/agave-xdp-compatibility}"
REPO_DIR="${REPO_DIR:-$HOME/agave-xdp-compatibility}"
DNS_TARGET="${DNS_TARGET:-1.1.1.1}"
IFACE="${1:-$(ip route get "$DNS_TARGET" 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')}"

say() { printf '%s\n' "$*"; }
line() { printf '%s\n' "============================================================"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    say "Missing required command: $1"
    exit 1
  }
}

if [[ -z "${IFACE:-}" ]]; then
  say "Could not detect interface. Usage: $0 <iface>"
  exit 1
fi

if ! ip link show dev "$IFACE" >/dev/null 2>&1; then
  say "Interface not found: $IFACE"
  exit 1
fi

for cmd in git cargo rustc ethtool ip lscpu setcap getcap; do
  need_cmd "$cmd"
done

host="$(hostname)"
os="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"
kernel="$(uname -r)"
src_ip="$(ip route get "$DNS_TARGET" 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
route_line="$(ip route get "$DNS_TARGET" 2>/dev/null | head -n1)"

driver="$(ethtool -i "$IFACE" 2>/dev/null | awk -F': ' '/^driver:/ {print $2}')"
driver_ver="$(ethtool -i "$IFACE" 2>/dev/null | awk -F': ' '/^version:/ {print $2}')"
firmware="$(ethtool -i "$IFACE" 2>/dev/null | awk -F': ' '/^firmware-version:/ {print $2}')"
bus_info="$(ethtool -i "$IFACE" 2>/dev/null | awk -F': ' '/^bus-info:/ {print $2}')"

speed="$(ethtool "$IFACE" 2>/dev/null | awk -F': ' '/Speed:/ {print $2}')"
duplex="$(ethtool "$IFACE" 2>/dev/null | awk -F': ' '/Duplex:/ {print $2}')"
link="$(ethtool "$IFACE" 2>/dev/null | awk -F': ' '/Link detected:/ {print $2}')"
port="$(ethtool "$IFACE" 2>/dev/null | awk -F': ' '/Port:/ {print $2}')"

rx_ring="$(ethtool -g "$IFACE" 2>/dev/null | awk '
  /Current hardware settings:/ {in_cur=1; next}
  in_cur && $1=="RX:" {gsub(/[[:space:]]/, "", $2); print $2; exit}
')"
tx_ring="$(ethtool -g "$IFACE" 2>/dev/null | awk '
  /Current hardware settings:/ {in_cur=1; next}
  in_cur && $1=="TX:" {gsub(/[[:space:]]/, "", $2); print $2; exit}
')"

numa_nodes="$(lscpu 2>/dev/null | awk -F: '/NUMA node\(s\)/ {gsub(/^[ \t]+/, "", $2); print $2}')"
cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
cpu_count="$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\):/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"

bond_master="none"
if [[ -L "/sys/class/net/$IFACE/master" ]]; then
  bond_master="$(basename "$(readlink -f "/sys/class/net/$IFACE/master")")"
fi

line
say "XDP Server Check"
line
printf '%-18s %s\n' "Host:" "$host"
printf '%-18s %s\n' "OS:" "$os"
printf '%-18s %s\n' "Kernel:" "$kernel"
printf '%-18s %s\n' "CPU:" "$cpu_model"
printf '%-18s %s\n' "CPU count:" "$cpu_count"
printf '%-18s %s\n' "NUMA nodes:" "${numa_nodes:-unknown}"
printf '%-18s %s\n' "Interface:" "$IFACE"
printf '%-18s %s\n' "Source IP:" "${src_ip:-unknown}"
printf '%-18s %s\n' "Route:" "${route_line:-unknown}"
printf '%-18s %s\n' "Bond master:" "$bond_master"

say ""
say "NIC"
printf '%-18s %s\n' "Driver:" "${driver:-unknown}"
printf '%-18s %s\n' "Driver version:" "${driver_ver:-unknown}"
printf '%-18s %s\n' "Firmware:" "${firmware:-unknown}"
printf '%-18s %s\n' "PCI bus:" "${bus_info:-unknown}"
printf '%-18s %s\n' "Port:" "${port:-unknown}"
printf '%-18s %s\n' "Speed:" "${speed:-unknown}"
printf '%-18s %s\n' "Duplex:" "${duplex:-unknown}"
printf '%-18s %s\n' "Link detected:" "${link:-unknown}"
printf '%-18s %s\n' "RX ring:" "${rx_ring:-unknown}"
printf '%-18s %s\n' "TX ring:" "${tx_ring:-unknown}"

say ""
say "Preparing agave-xdp-compatibility"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone --depth 1 "$REPO_URL" "$REPO_DIR"
else
  git -C "$REPO_DIR" fetch --depth 1 origin
  git -C "$REPO_DIR" reset --hard origin/HEAD
fi

cargo build --release --manifest-path "$REPO_DIR/Cargo.toml"

BIN="$REPO_DIR/target/release/xdp-compatibility"
if [[ ! -x "$BIN" ]]; then
  say "Build completed, but binary not found: $BIN"
  exit 1
fi

XDP_RESULT="not-run"
ZC_RESULT="not-run"
XDP_STATUS="UNKNOWN"
ZC_STATUS="UNKNOWN"
OVERALL="UNKNOWN"

say ""
say "Running XDP probe"
setcap cap_net_admin,cap_net_raw,cap_bpf+ep "$BIN"
if RUST_LOG=info "$BIN" "$DNS_TARGET" --xdp-interface "$IFACE" --timeout-ms 1000; then
  XDP_RESULT="passed"
  XDP_STATUS="GOOD for XDP"
else
  XDP_RESULT="failed"
  XDP_STATUS="NOT GOOD for XDP"
fi

say ""
say "Running Zero-Copy probe"
if [[ "$bond_master" != "none" ]]; then
  ZC_RESULT="skipped"
  ZC_STATUS="NOT RECOMMENDED for Zero-Copy (bonded interface)"
elif [[ "${driver:-}" == "bnxt_en" ]]; then
  ZC_RESULT="skipped"
  ZC_STATUS="NOT RECOMMENDED for Zero-Copy (bnxt_en)"
else
  setcap cap_net_admin,cap_net_raw,cap_bpf,cap_perfmon+ep "$BIN"
  if RUST_LOG=info "$BIN" "$DNS_TARGET" --xdp-interface "$IFACE" --timeout-ms 1000 --xdp-zero-copy; then
    ZC_RESULT="passed"
    ZC_STATUS="GOOD for Zero-Copy"
  else
    ZC_RESULT="failed"
    ZC_STATUS="NOT GOOD for Zero-Copy"
  fi
fi

if [[ "$XDP_RESULT" == "passed" && "$ZC_RESULT" == "passed" ]]; then
  OVERALL="GOOD for XDP and Zero-Copy"
elif [[ "$XDP_RESULT" == "passed" && "$ZC_RESULT" == "skipped" ]]; then
  OVERALL="GOOD for XDP; Zero-Copy not recommended on this setup"
elif [[ "$XDP_RESULT" == "passed" ]]; then
  OVERALL="GOOD for XDP; Zero-Copy failed"
else
  OVERALL="NOT GOOD for XDP"
fi

say ""
line
say "Final Result"
line
printf '%-18s %s\n' "Host:" "$host"
printf '%-18s %s\n' "Interface:" "$IFACE"
printf '%-18s %s\n' "Driver:" "${driver:-unknown}"
printf '%-18s %s\n' "Firmware:" "${firmware:-unknown}"
printf '%-18s %s\n' "Kernel:" "$kernel"
printf '%-18s %s\n' "XDP probe:" "$XDP_RESULT"
printf '%-18s %s\n' "Zero-copy probe:" "$ZC_RESULT"
printf '%-18s %s\n' "XDP verdict:" "$XDP_STATUS"
printf '%-18s %s\n' "Zero-copy verdict:" "$ZC_STATUS"
printf '%-18s %s\n' "Overall:" "$OVERALL"
say ""
