#!/bin/bash

set -euo pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (use sudo)."
id -u sol >/dev/null 2>&1 || die "User 'sol' not found."


# Usage / arg check
if [[ -z "$1" ]]; then
  echo "Usage: $0 <mainnet|testnet>"
  exit 1
fi

CLUSTER="$1"

sudo -u sol -H bash -lc '
set -euo pipefail
cd "$HOME"

if [[ -d "$HOME/bin" ]]; then
    echo "Directory exists"
else
    mkdir -p "$HOME/bin"
fi

if [[ -f "$HOME/bin/start.sh" ]]; then
    echo "start exists"
else
    touch "$HOME/bin/start.sh"
fi
'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy cluster-specific start script
case "$CLUSTER" in
  mainnet)
    info "Setting up mainnet start script"
    cp "$SCRIPT_DIR/mainnet.start.sh" /home/sol/bin/start.sh
    ;;
  testnet)
    info "Setting up testnet start script"
    cp "$SCRIPT_DIR/testnet.start.sh" /home/sol/bin/start.sh
    ;;
  *)
    die "Unknown cluster: $CLUSTER (must be mainnet or testnet)"
    ;;
esac

ok "added start scripts for $CLUSTER"

sudo chown -R sol:sol /home/sol/bin
