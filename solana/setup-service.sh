#!/bin/bash

set -euo pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (use sudo)."

info "Setting up service file"
cp "$SCRIPT_DIR/example.sol.service" /etc/systemd/system/sol.service


ok "added system service file"
