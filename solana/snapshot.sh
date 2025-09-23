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

# Clean up filenames and move them
for f in *\?*; do
  base="${f%%\?*}"               # strip query params
  clean="${base%.tar.*}.tar.zst" # normalize extension
  mv "$f" "/mnt/snapshots/$clean"
done

# Change ownership to sol user
chown sol:sol /mnt/snapshots/*.tar.zst
