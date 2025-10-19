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

# Check if solana CLI is available for sol user
if ! sudo -u sol command -v solana &> /dev/null; then
    die "Solana CLI is not installed or not in PATH for sol user"
fi

# Check if doublezero is available for sol user
if ! sudo -u sol command -v doublezero &> /dev/null; then
    die "Doublezero is not installed or not in PATH for sol user"
fi

# Check if solana-keygen is available for sol user
if ! sudo -u sol command -v solana-keygen &> /dev/null; then
    die "Solana-keygen is not installed or not in PATH for sol user"
fi

info "Generating offchain message signature..."
info "Validator keypair: $VALIDATOR_KEYPAIR"

# Get doublezero address as sol user
info "Getting doublezero address..."
DOUBLEZERO_ADDRESS=$(sudo -u sol doublezero address 2>/dev/null)

if [ -z "$DOUBLEZERO_ADDRESS" ]; then
    die "Failed to get doublezero address as sol user. Make sure doublezero is properly configured for the sol user."
fi

info "Doublezero address: $DOUBLEZERO_ADDRESS"

# Generate the offchain message signature as sol user
info "Signing offchain message..."
SIGNATURE=$(sudo -u sol solana sign-offchain-message -k "$VALIDATOR_KEYPAIR" "service_key=$DOUBLEZERO_ADDRESS")

if [ -z "$SIGNATURE" ]; then
    die "Failed to generate signature as sol user"
fi

ok "Offchain message signature generated successfully!"
info "Signature: $SIGNATURE"

# Get validator identity (public key) as sol user
info "Getting validator identity..."
VALIDATOR_IDENTITY=$(sudo -u sol solana-keygen pubkey "$VALIDATOR_KEYPAIR")

if [ -z "$VALIDATOR_IDENTITY" ]; then
    die "Failed to get validator identity from keypair as sol user"
fi

info "Validator identity: $VALIDATOR_IDENTITY"

# Check if doublezero-solana CLI is available for sol user
if ! sudo -u sol command -v doublezero-solana &> /dev/null; then
    warn "doublezero-solana CLI not found for sol user. Skipping passport request."
    info ""
    info "Manual passport request command (run as sol user):"
    info "sudo -u sol doublezero-solana passport request-validator-access -u mainnet-beta \\"
    info "  -k $VALIDATOR_KEYPAIR \\"
    info "  --primary-validator-id $VALIDATOR_IDENTITY \\"
    info "  --signature $SIGNATURE \\"
    info "  --doublezero-address $DOUBLEZERO_ADDRESS"
    exit 0
fi

# Make the passport request as sol user
info "Making passport request to Doublezero as sol user..."
sudo -u sol doublezero-solana passport request-validator-access -u mainnet-beta \
  -k "$VALIDATOR_KEYPAIR" \
  --primary-validator-id "$VALIDATOR_IDENTITY" \
  --signature "$SIGNATURE" \
  --doublezero-address "$DOUBLEZERO_ADDRESS"

ok "Passport request completed successfully!"
info ""
info "Validator registration details:"
info "  Validator keypair: $VALIDATOR_KEYPAIR"
info "  Validator identity: $VALIDATOR_IDENTITY"
info "  Doublezero address: $DOUBLEZERO_ADDRESS"
info "  Signature: $SIGNATURE"