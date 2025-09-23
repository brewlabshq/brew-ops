#!/bin/bash

set -eou pipefail

# Check input
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 [mainnet|testnet]"
  exit 1
fi

network="$1"

# Choose base URL based on input
case "$network" in
  mainnet)
    base_url="https://snapshots.avorio.network/mainnet-beta"
    ;;
  testnet)
    base_url="https://snapshots.avorio.network/testnet"
    ;;
  *)
    echo "Invalid network: $network"
    echo "Usage: $0 [mainnet|testnet]"
    exit 1
    ;;
esac

# Create snapshots directory if it doesn't exist
mkdir -p /mnt/snapshots

# Download files with aria2c
aria2c -x16 -s16 --force-sequential=true --allow-overwrite=true \
  --auto-file-renaming=false \
  "$base_url/snapshot.tar.bz2" \
  "$base_url/incremental-snapshot.tar.bz2"


mv /home/ubuntu/brew-ops/solana/*.tar.zst /mnt/snapshots

# Change ownership to sol user
chown sol:sol /mnt/snapshots/*.tar.zst
