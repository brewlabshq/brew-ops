#!/bin/bash

set -eou pipefail


die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# Check if required dependencies exist
check_dependencies() {
    local missing_deps=()
    
    if ! command -v agave-validator &> /dev/null; then
        missing_deps+=("agave-validator")
    fi
    
    if ! command -v solana-keygen &> /dev/null; then
        missing_deps+=("solana-keygen")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        die "Missing required dependencies: ${missing_deps[*]}. Please install them before running this script."
    fi
}

# Check dependencies before proceeding
info "Checking dependencies..."
check_dependencies
ok "All dependencies found"

# Check if identity file path is provided as argument
if [ $# -eq 0 ]; then
    die "Usage: $0 <identity-file-path>"
fi

IDENTITY_FILE="$1"

# Check if the identity file exists
if [ ! -f "$IDENTITY_FILE" ]; then
    die "Identity file '$IDENTITY_FILE' does not exist"
fi

info "Setting identity from: $IDENTITY_FILE (without tower requirement)"
agave-validator -l /mnt/ledger set-identity "$IDENTITY_FILE"
ln -sf "$IDENTITY_FILE" /home/sol/id.json
ok "Identity set successfully (no tower requirement)"
