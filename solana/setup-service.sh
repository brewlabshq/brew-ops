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

read -rp "Enter validator identity pubkey: " INPUT_IDENTITY_PUBKEY
[[ -n "$INPUT_IDENTITY_PUBKEY" ]] || die "Identity pubkey cannot be empty."

read -rp "Enter primary identity file path (e.g. /home/sol/vote-identity.json): " INPUT_PRIMARY_IDENTITY
[[ -n "$INPUT_PRIMARY_IDENTITY" ]] || die "Primary identity path cannot be empty."

read -rp "Enter RPC URL (e.g. https://mainnet.helius-rpc.com/?api-key=...): " INPUT_RPC_URL
[[ -n "$INPUT_RPC_URL" ]] || die "RPC URL cannot be empty."

mkdir -p /home/sol/bin
cp "$SCRIPT_DIR/pre-start.sh" /home/sol/bin/pre-start.sh

sed -i "s|PLACEHOLDER_IDENTITY_PUBKEY|$INPUT_IDENTITY_PUBKEY|g" /home/sol/bin/pre-start.sh
sed -i "s|PLACEHOLDER_PRIMARY_IDENTITY|$INPUT_PRIMARY_IDENTITY|g" /home/sol/bin/pre-start.sh
sed -i "s|PLACEHOLDER_RPC_URL|$INPUT_RPC_URL|g" /home/sol/bin/pre-start.sh

chmod +x /home/sol/bin/pre-start.sh
chown sol:sol /home/sol/bin/pre-start.sh
ok "installed pre-start.sh"
