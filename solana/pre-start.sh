#!/bin/bash

set -euo pipefail

TEMP_IDENTITY=/home/sol/temp.json
IDENTITY_LINK=/home/sol/id.json

if [ ! -f "$TEMP_IDENTITY" ]; then
    echo "ERROR: temp identity $TEMP_IDENTITY not found, refusing to start" >&2
    exit 1
fi

# Always reset to temp identity on start to prevent double-signing after failover
ln -sf "$TEMP_IDENTITY" "$IDENTITY_LINK"
echo "Identity reset to temp key: $(solana-keygen pubkey $TEMP_IDENTITY)"
