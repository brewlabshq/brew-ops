#!/bin/bash

set -euo pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (use sudo)."


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Setting up service file"
cp "$SCRIPT_DIR/example.sol.service" /etc/systemd/system/sol.service
ok "added system service file"

info "Installing pre-start.sh to /home/sol/bin/"
mkdir -p /home/sol/bin
cp "$SCRIPT_DIR/pre-start.sh" /home/sol/bin/pre-start.sh
chmod +x /home/sol/bin/pre-start.sh
chown sol:sol /home/sol/bin/pre-start.sh
ok "installed pre-start.sh"
