#!/bin/bash

set -euo pipefail

IDENTITY_PUBKEY="PLACEHOLDER_IDENTITY_PUBKEY"
PRIMARY_IDENTITY="PLACEHOLDER_PRIMARY_IDENTITY"
TEMP_IDENTITY=/home/sol/temp.json
IDENTITY_LINK=/home/sol/id.json
GOSSIP_LOOPS=8
GOSSIP_INTERVAL=1
RPC_URL="PLACEHOLDER_RPC_URL"

if [ ! -f "$TEMP_IDENTITY" ]; then
    echo "ERROR: $TEMP_IDENTITY not found, refusing to start" >&2
    exit 1
fi

if [ ! -f "$PRIMARY_IDENTITY" ]; then
    echo "ERROR: $PRIMARY_IDENTITY not found, refusing to start" >&2
    exit 1
fi

MY_IP=$(curl -s --max-time 5 ifconfig.me)
if [ -z "$MY_IP" ]; then
    echo "WARNING: could not determine server IP, defaulting to temp identity" >&2
    ln -sf "$TEMP_IDENTITY" "$IDENTITY_LINK"
    exit 0
fi

echo "Server IP: $MY_IP"

GOSSIP_IP=""
GOSSIP_CHECK_OK=0

for i in $(seq 1 $GOSSIP_LOOPS); do
    echo "Gossip check $i/$GOSSIP_LOOPS..."

    RESPONSE=$(curl -s --max-time 10 -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' || true)

    if [ -z "$RESPONSE" ]; then
        echo "WARNING: empty RPC response"
        sleep $GOSSIP_INTERVAL
        continue
    fi

    if ! echo "$RESPONSE" | jq -e '.result' >/dev/null 2>&1; then
        echo "WARNING: RPC response did not contain .result"
        sleep $GOSSIP_INTERVAL
        continue
    fi

    GOSSIP_CHECK_OK=1

    GOSSIP_IP=$(echo "$RESPONSE" | jq -r \
        ".result[] | select(.pubkey == \"$IDENTITY_PUBKEY\") | .gossip // empty" | \
        head -n1 | cut -d: -f1)

    if [ -n "$GOSSIP_IP" ]; then
        echo "Found identity in gossip at IP: $GOSSIP_IP"
        break
    fi
    sleep $GOSSIP_INTERVAL
done

if [ "$GOSSIP_CHECK_OK" -ne 1 ]; then
    echo "WARNING: could not verify gossip state, starting with temp identity"
    ln -sf "$TEMP_IDENTITY" "$IDENTITY_LINK"
elif [ -z "$GOSSIP_IP" ]; then
    echo "WARNING: identity not found in gossip, treating as inconclusive, starting with temp identity"
    ln -sf "$TEMP_IDENTITY" "$IDENTITY_LINK"
elif [ "$GOSSIP_IP" != "$MY_IP" ]; then
    echo "Identity is live on a different server ($GOSSIP_IP), starting with temp identity"
    ln -sf "$TEMP_IDENTITY" "$IDENTITY_LINK"
else
    echo "Identity is on this server ($MY_IP), starting with primary identity"
    ln -sf "$PRIMARY_IDENTITY" "$IDENTITY_LINK"
fi
