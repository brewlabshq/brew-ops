#!/bin/bash

set -eou pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# Check if validator keypair path is provided as argument
if [ $# -eq 0 ]; then
    die "Usage: $0 <path/to/validator-keypair.json>"
fi

VALIDATOR_KEYPAIR="$1"

# Validate validator keypair file
if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
    die "Validator keypair file '$VALIDATOR_KEYPAIR' does not exist"
fi

# Debug: Check sol user's PATH
info "Debugging sol user environment..."
info "Sol user PATH: $(sudo -u sol bash -lc 'echo $PATH')"

# Check if solana CLI is available for sol user (with proper environment)
if ! sudo -u sol bash -lc 'command -v solana' &> /dev/null; then
    warn "Solana CLI not found in PATH, trying direct path..."
    if [ ! -f "/home/sol/.local/share/solana/install/active_release/bin/solana" ]; then
        die "Solana CLI is not installed. Please install Solana first."
    fi
    info "Found Solana CLI at direct path"
else
    info "Found Solana CLI in PATH"
fi

# Check if doublezero is available for sol user (with proper environment)
if ! sudo -u sol bash -lc 'command -v doublezero' &> /dev/null; then
    die "Doublezero is not installed or not in PATH for sol user"
fi

# Check if solana-keygen is available for sol user (with proper environment)
if ! sudo -u sol bash -lc 'command -v solana-keygen' &> /dev/null; then
    warn "Solana-keygen not found in PATH, trying direct path..."
    if [ ! -f "/home/sol/.local/share/solana/install/active_release/bin/solana-keygen" ]; then
        die "Solana-keygen is not installed. Please install Solana first."
    fi
    info "Found Solana-keygen at direct path"
else
    info "Found Solana-keygen in PATH"
fi

info "Generating offchain message signature..."
info "Validator keypair: $VALIDATOR_KEYPAIR"

# Get doublezero address as sol user (with proper environment)
info "Getting doublezero address..."
DOUBLEZERO_ADDRESS=$(sudo -u sol bash -lc 'doublezero address' 2>/dev/null)

if [ -z "$DOUBLEZERO_ADDRESS" ]; then
    die "Failed to get doublezero address as sol user. Make sure doublezero is properly configured for the sol user."
fi

info "Doublezero address: $DOUBLEZERO_ADDRESS"

# Generate the offchain message signature as sol user (with proper environment)
info "Signing offchain message..."
if sudo -u sol bash -lc 'command -v solana' &> /dev/null; then
    SIGNATURE=$(sudo -u sol bash -lc "solana sign-offchain-message -k '$VALIDATOR_KEYPAIR' 'service_key=$DOUBLEZERO_ADDRESS'" 2>/dev/null)
else
    SIGNATURE=$(sudo -u sol bash -lc "/home/sol/.local/share/solana/install/active_release/bin/solana sign-offchain-message -k '$VALIDATOR_KEYPAIR' 'service_key=$DOUBLEZERO_ADDRESS'" 2>/dev/null)
fi

if [ -z "$SIGNATURE" ]; then
    die "Failed to generate signature as sol user"
fi

ok "Offchain message signature generated successfully!"
info "Signature: $SIGNATURE"

# Get validator identity (public key) as sol user (with proper environment)
info "Getting validator identity..."
if sudo -u sol bash -lc 'command -v solana-keygen' &> /dev/null; then
    VALIDATOR_IDENTITY=$(sudo -u sol bash -lc "solana-keygen pubkey '$VALIDATOR_KEYPAIR'" 2>/dev/null)
else
    VALIDATOR_IDENTITY=$(sudo -u sol bash -lc "/home/sol/.local/share/solana/install/active_release/bin/solana-keygen pubkey '$VALIDATOR_KEYPAIR'" 2>/dev/null)
fi

if [ -z "$VALIDATOR_IDENTITY" ]; then
    die "Failed to get validator identity from keypair as sol user"
fi

info "Validator identity: $VALIDATOR_IDENTITY"

# Check if doublezero-solana CLI is available for sol user (with proper environment)
if ! sudo -u sol bash -lc 'command -v doublezero-solana' &> /dev/null; then
    warn "doublezero-solana CLI not found for sol user. Skipping passport request."
    info ""
    info "Manual passport request command (run as sol user):"
    info "sudo -u sol bash -lc 'doublezero-solana passport request-validator-access -u mainnet-beta \\"
    info "  -k $VALIDATOR_KEYPAIR \\"
    info "  --primary-validator-id $VALIDATOR_IDENTITY \\"
    info "  --signature $SIGNATURE \\"
    info "  --doublezero-address $DOUBLEZERO_ADDRESS'"
    exit 0
fi

# Make the passport request as sol user (with proper environment)
info "Making passport request to Doublezero as sol user..."
sudo -u sol bash -lc "doublezero-solana passport request-validator-access -u mainnet-beta \
  -k '$VALIDATOR_KEYPAIR' \
  --primary-validator-id '$VALIDATOR_IDENTITY' \
  --signature '$SIGNATURE' \
  --doublezero-address '$DOUBLEZERO_ADDRESS'"

ok "Passport request completed successfully!"
info ""
info "Validator registration details:"
info "  Validator keypair: $VALIDATOR_KEYPAIR"
info "  Validator identity: $VALIDATOR_IDENTITY"
info "  Doublezero address: $DOUBLEZERO_ADDRESS"
info "  Signature: $SIGNATURE"