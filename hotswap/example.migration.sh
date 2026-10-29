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

    if ! command -v scp &> /dev/null; then
        missing_deps+=("scp")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        die "Missing required dependencies: ${missing_deps[*]}. Please install them before running this script."
    fi
}

# Check dependencies before proceeding
info "Checking dependencies..."
check_dependencies
ok "All dependencies found"

# Check if required arguments are provided
if [ $# -lt 3 ]; then
    die "Usage: $0 <ssh-destination> <identity-file-path> <tempory-identity-path>"
fi

SSH_DEST="$1"
IDENTITY_FILE="$2"
TEMP_IDENTITY_FILE="$3"

# Check if the identity file exists
if [ ! -f "$IDENTITY_FILE" ]; then
    die "Identity file '$IDENTITY_FILE' does not exist"
fi
# Check if the identity file exists
if [ ! -f "$TEMP_IDENTITY_FILE" ]; then
    die "Identity file '$IDENTITY_FILE' does not exist"
fi

# Check SSH connection
check_ssh_connection() {
    info "Testing SSH connection to $SSH_DEST..."
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$SSH_DEST" "echo 'SSH connection successful'" &> /dev/null; then
        ok "SSH connection to $SSH_DEST is working"
    else
        die "Cannot establish SSH connection to $SSH_DEST. Please check your SSH configuration and network connectivity."
    fi
}

info "Starting migration process..."
info "SSH destination: $SSH_DEST"
info "Identity file: $IDENTITY_FILE"
info "Temp Identity file: $TEMP_IDENTITY_FILE"

# Test SSH connection before proceeding
check_ssh_connection

# Wait for restart window
info "Waiting for restart window..."
agave-validator -l /mnt/ledger wait-for-restart-window --min-idle-time 2 --skip-new-snapshot-check

# Set identity
info "Setting identity from: $TEMP_IDENTITY_FILE"
agave-validator -l /mnt/ledger set-identity "$TEMP_IDENTITY_FILE"
ln -sf "$TEMP_IDENTITY_FILE" /home/sol/id.json

# Get the public key from the identity file for vote-history file naming
PUBKEY=$(solana-keygen pubkey "$IDENTITY_FILE")
VOTE_HISTORY_FILE="/mnt/ledger/vote_history-${PUBKEY}.bin"

# Check if vote-history file exists
if [ ! -f "$VOTE_HISTORY_FILE" ]; then
    warn "Vote-history file '$VOTE_HISTORY_FILE' does not exist, but continuing with SCP..."
fi

# Copy vote-history file to remote server
info "Copying vote-history file to remote server..."
scp "$VOTE_HISTORY_FILE" "$SSH_DEST:/mnt/ledger"

ok "Migration completed successfully"
