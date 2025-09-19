#!/usr/bin/env bash
set -euo pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# Usage / arg check
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <agave|firedancer>"
  exit 1
fi

MODE="$1"

# Require root and ufw present
[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (use sudo)."
command -v ufw >/dev/null 2>&1 || die "ufw is not installed. Install it (e.g., apt install ufw)."

open_ports() {
  local mode="$1"
  info "Opening ports for '${mode}'..."

  if [[ "$mode" == "agave" ]]; then
    info "Allowing 8000-8025 (tcp/udp)"
    ufw allow 8000:8025/tcp
    ufw allow 8000:8025/udp

  elif [[ "$mode" == "firedancer" ]]; then
    info "Allowing 8900-9000 (tcp/udp) and 8001"
    ufw allow 8900:9000/tcp
    ufw allow 8900:9000/udp
    ufw allow 8001

  else
    die "Invalid option: $mode (expected: agave or firedancer)"
  fi

  # Apply rules (won't enable ufw if it's disabled)
  ufw reload || warn "ufw reload failed (is ufw enabled?)"

  ok "Rules added. Current ufw status:"
  ufw status verbose || true
}

open_ports "$MODE"
