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

is_bond_device() {
  [[ -d "/sys/class/net/$1/bonding" ]]
}

bond_members_for() {
  local iface="$1"
  if [[ -r "/sys/class/net/$iface/bonding/slaves" ]]; then
    tr ' ' '\n' < "/sys/class/net/$iface/bonding/slaves" | sed '/^$/d'
  fi
}

bond_master_for() {
  local iface="$1"
  if [[ -L "/sys/class/net/$iface/master" ]]; then
    basename "$(readlink -f "/sys/class/net/$iface/master")"
  else
    echo "none"
  fi
}

join_by_comma() {
  paste -sd ', ' -
}

prepare_checker() {
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
}

print_host_header() {
  local iface="$1"
  local host os kernel cpu_model cpu_count numa_nodes src_ip route_line
  local is_bond="no" bond_master="none" members=""

  host="$(hostname)"
  os="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"
  kernel="$(uname -r)"
  cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
  cpu_count="$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\):/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
  numa_nodes="$(lscpu 2>/dev/null | awk -F: '/NUMA node\(s\)/ {gsub(/^[ \t]+/, "", $2); print $2}')"
  src_ip="$(ip route get "$DNS_TARGET" 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
  route_line="$(ip route get "$DNS_TARGET" 2>/dev/null | head -n1)"

  if is_bond_device "$iface"; then
    is_bond="yes"
    members="$(bond_members_for "$iface" | join_by_comma || true)"
  fi
  bond_master="$(bond_master_for "$iface")"

  line
  say "XDP Server Check"
  line
  printf '%-18s %s\n' "Host:" "$host"
  printf '%-18s %s\n' "OS:" "$os"
  printf '%-18s %s\n' "Kernel:" "$kernel"
  printf '%-18s %s\n' "CPU:" "$cpu_model"
  printf '%-18s %s\n' "CPU count:" "$cpu_count"
  printf '%-18s %s\n' "NUMA nodes:" "${numa_nodes:-unknown}"
  printf '%-18s %s\n' "Interface:" "$iface"
  printf '%-18s %s\n' "Source IP:" "${src_ip:-unknown}"
  printf '%-18s %s\n' "Route:" "${route_line:-unknown}"
  printf '%-18s %s\n' "Is bond device:" "$is_bond"
  printf '%-18s %s\n' "Bond master:" "$bond_master"
  if [[ "$is_bond" == "yes" ]]; then
    printf '%-18s %s\n' "Bond members:" "${members:-unknown}"
  fi
  say ""
}

probe_iface() {
  local iface="$1"
  local driver driver_ver firmware bus_info speed duplex link port rx_ring tx_ring bond_master
  local xdp_result="not-run" zc_result="not-run" xdp_status="UNKNOWN" zc_status="UNKNOWN" overall="UNKNOWN"

  driver="$(ethtool -i "$iface" 2>/dev/null | awk -F': ' '/^driver:/ {print $2}')"
  driver_ver="$(ethtool -i "$iface" 2>/dev/null | awk -F': ' '/^version:/ {print $2}')"
  firmware="$(ethtool -i "$iface" 2>/dev/null | awk -F': ' '/^firmware-version:/ {print $2}')"
  bus_info="$(ethtool -i "$iface" 2>/dev/null | awk -F': ' '/^bus-info:/ {print $2}')"
  speed="$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Speed:/ {print $2}')"
  duplex="$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Duplex:/ {print $2}')"
  link="$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Link detected:/ {print $2}')"
  port="$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Port:/ {print $2}')"
  rx_ring="$(
    ethtool -g "$iface" 2>/dev/null | awk '
      /Current hardware settings:/ {in_cur=1; next}
      in_cur && $1=="RX:" {gsub(/[[:space:]]/, "", $2); print $2; exit}
    ' || true
  )"
  tx_ring="$(
    ethtool -g "$iface" 2>/dev/null | awk '
      /Current hardware settings:/ {in_cur=1; next}
      in_cur && $1=="TX:" {gsub(/[[:space:]]/, "", $2); print $2; exit}
    ' || true
  )"
  bond_master="$(bond_master_for "$iface")"

  say "NIC: $iface"
  printf '%-18s %s\n' "Driver:" "${driver:-unknown}"
  printf '%-18s %s\n' "Driver version:" "${driver_ver:-unknown}"
  printf '%-18s %s\n' "Firmware:" "${firmware:-unknown}"
  printf '%-18s %s\n' "PCI bus:" "${bus_info:-unknown}"
  printf '%-18s %s\n' "Port:" "${port:-unknown}"
  printf '%-18s %s\n' "Speed:" "${speed:-unknown}"
  printf '%-18s %s\n' "Duplex:" "${duplex:-unknown}"
  printf '%-18s %s\n' "Link detected:" "${link:-unknown}"
  printf '%-18s %s\n' "RX ring:" "${rx_ring:-unsupported}"
  printf '%-18s %s\n' "TX ring:" "${tx_ring:-unsupported}"
  printf '%-18s %s\n' "Bond master:" "$bond_master"

  say ""
  say "Running XDP probe on $iface"
  setcap cap_net_admin,cap_net_raw,cap_bpf+ep "$BIN"
  if RUST_LOG=info "$BIN" "$DNS_TARGET" --xdp-interface "$iface" --timeout-ms 1000; then
    xdp_result="passed"
    xdp_status="GOOD for XDP"
  else
    xdp_result="failed"
    xdp_status="NOT GOOD for XDP"
  fi

  say ""
  say "Running Zero-Copy probe on $iface"
  if [[ "$bond_master" != "none" ]]; then
    zc_result="skipped"
    zc_status="NOT RECOMMENDED for Zero-Copy (bonded interface)"
  elif [[ "${driver:-}" == "bnxt_en" ]]; then
    zc_result="skipped"
    zc_status="NOT RECOMMENDED for Zero-Copy (bnxt_en)"
  else
    setcap cap_net_admin,cap_net_raw,cap_bpf,cap_perfmon+ep "$BIN"
    if RUST_LOG=info "$BIN" "$DNS_TARGET" --xdp-interface "$iface" --timeout-ms 1000 --xdp-zero-copy; then
      zc_result="passed"
      zc_status="GOOD for Zero-Copy"
    else
      zc_result="failed"
      zc_status="NOT GOOD for Zero-Copy"
    fi
  fi

  if [[ "$xdp_result" == "passed" && "$zc_result" == "passed" ]]; then
    overall="GOOD for XDP and Zero-Copy"
  elif [[ "$xdp_result" == "passed" && "$zc_result" == "skipped" ]]; then
    overall="GOOD for XDP; Zero-Copy not recommended on this setup"
  elif [[ "$xdp_result" == "passed" ]]; then
    overall="GOOD for XDP; Zero-Copy failed"
  else
    overall="NOT GOOD for XDP"
  fi

  say ""
  printf '%-18s %s\n' "XDP probe:" "$xdp_result"
  printf '%-18s %s\n' "Zero-copy probe:" "$zc_result"
  printf '%-18s %s\n' "XDP verdict:" "$xdp_status"
  printf '%-18s %s\n' "Zero-copy verdict:" "$zc_status"
  printf '%-18s %s\n' "Overall:" "$overall"
  say ""

  printf '%s|%s|%s|%s|%s\n' "$iface" "${driver:-unknown}" "$xdp_result" "$zc_result" "$overall" >> "$SUMMARY_FILE"
}

for cmd in git cargo rustc ethtool ip lscpu setcap getcap; do
  need_cmd "$cmd"
done

if [[ -z "${IFACE:-}" ]]; then
  say "Could not detect interface. Usage: $0 <iface>"
  exit 1
fi

if ! ip link show dev "$IFACE" >/dev/null 2>&1; then
  say "Interface not found: $IFACE"
  exit 1
fi

prepare_checker

SUMMARY_FILE="$(mktemp)"
trap 'rm -f "$SUMMARY_FILE"' EXIT

print_host_header "$IFACE"

if is_bond_device "$IFACE"; then
  say "Selected interface is a bond. Probing physical member NICs instead."
  say ""
  while IFS= read -r member; do
    [[ -n "$member" ]] || continue
    probe_iface "$member"
  done < <(bond_members_for "$IFACE")
else
  probe_iface "$IFACE"
fi

line
say "Final Result"
line

healthy_xdp="$(awk -F'|' '$3=="passed" {print $1}' "$SUMMARY_FILE" | join_by_comma || true)"
healthy_zc="$(awk -F'|' '$4=="passed" {print $1}' "$SUMMARY_FILE" | join_by_comma || true)"

if [[ -n "${healthy_xdp:-}" ]]; then
  printf '%-18s %s\n' "Healthy for XDP:" "$healthy_xdp"
else
  printf '%-18s %s\n' "Healthy for XDP:" "none"
fi

if [[ -n "${healthy_zc:-}" ]]; then
  printf '%-18s %s\n' "Healthy for Zero-Copy:" "$healthy_zc"
else
  printf '%-18s %s\n' "Healthy for Zero-Copy:" "none"
fi

say ""
while IFS='|' read -r iface driver xdp_result zc_result overall; do
  printf '%-18s %s | driver=%s | xdp=%s | zero-copy=%s\n' "$iface" "$overall" "$driver" "$xdp_result" "$zc_result"
done < "$SUMMARY_FILE"
say ""
