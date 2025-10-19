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

# Check if solana CLI is available
if ! command -v solana &> /dev/null; then
    die "Solana CLI is not installed or not in PATH"
fi

# Check if doublezero is available
if ! command -v doublezero &> /dev/null; then
    die "Doublezero is not installed or not in PATH"
fi

info "Generating offchain message signature..."
info "Validator keypair: $VALIDATOR_KEYPAIR"

# Get doublezero address
info "Getting doublezero address..."
DOUBLEZERO_ADDRESS=$(sudo -u sol doublezero address 2>/dev/null || doublezero address 2>/dev/null)

if [ -z "$DOUBLEZERO_ADDRESS" ]; then
    die "Failed to get doublezero address. Make sure doublezero is properly configured."
fi

info "Doublezero address: $DOUBLEZERO_ADDRESS"

# Generate the offchain message signature
info "Signing offchain message..."
SIGNATURE=$(solana sign-offchain-message -k "$VALIDATOR_KEYPAIR" "service_key=$DOUBLEZERO_ADDRESS")

if [ -z "$SIGNATURE" ]; then
    die "Failed to generate signature"
fi

ok "Offchain message signature generated successfully!"
info "Signature: $SIGNATURE"

# Get validator identity (public key)
info "Getting validator identity..."
VALIDATOR_IDENTITY=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR")

if [ -z "$VALIDATOR_IDENTITY" ]; then
    die "Failed to get validator identity from keypair"
fi

info "Validator identity: $VALIDATOR_IDENTITY"

# Check if doublezero-solana CLI is available
if ! command -v doublezero-solana &> /dev/null; then
    warn "doublezero-solana CLI not found. Skipping passport request."
    info ""
    info "Manual passport request command:"
    info "doublezero-solana passport request-validator-access -u mainnet-beta \\"
    info "  -k $VALIDATOR_KEYPAIR \\"
    info "  --primary-validator-id $VALIDATOR_IDENTITY \\"
    info "  --signature $SIGNATURE \\"
    info "  --doublezero-address $DOUBLEZERO_ADDRESS"
    exit 0
fi

# Make the passport request
info "Making passport request to Doublezero..."
doublezero-solana passport request-validator-access -u mainnet-beta \
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