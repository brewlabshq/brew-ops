#!/bin/bash

set -eou pipefail

# Base CLI Value
IDENTITY_FILE=/home/sol/id.json
VOTE_ACCOUNT=/home/sol/vote.json
AUTHORIZED_VOTER=/home/sol/ice.json
LOG_FILE="/home/sol/logs/solana-validator.log"
LEDGER=/mnt/ledger
ACCOUNTS=/mnt/accounts


# JITO
TIP_PROGRAM_PUBKEY=GJHtFqM9agxPmkeKjHny6qiRKrXZALvvFGiKf11QE7hy
TIP_DISTRIBUTION_PROGRAM_PUBKEY=F2Zu7QZiTYUhPd7u9ukRVwxh7B71oA3NMJcHuCHc29P2
MERKLE_ROOT_UPLOAD_AUTHORITY=GZctHpWXmsZC1YHACTGGcHhYxjdRqQvTpYkb9LMvxDib
JITO_COMMISION_BPS=0
JITO_SHRED_RECEIVER_ADDRESS=141.98.218.12:1002
JITO_BLOCK_ENGINE_URL=https://dallas.testnet.block-engine.jito.wtf


if [[ -d /mnt/ledger/snapshot-store ]]; then
    SNAPSHOT=mnt/ledger/snapshot-store
else
	SNAPSHOT=/mnt/snapshot
fi

#!/bin/bash
exec /home/sol/.local/share/solana/install/active_release/bin/agave-validator  \
    --identity $IDENTITY_FILE \
    --vote-account $VOTE_ACCOUNT \
    --authorized-voter $AUTHORIZED_VOTER \
    --known-validator 5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on \
    --known-validator 7XSY3MrYnK8vq693Rju17bbPkCN3Z7KvvfvJx4kdrsSY \
    --known-validator Ft5fbkqNa76vnsjYNwjDZUXoTWpP7VYm3mtsaQckQADN \
    --known-validator 9QxCLckBiJc783jnMvXZubK4wH86Eqqvashtrwvcsgkv \
    --known-validator eoKpUABi59aT4rR9HGS3LcMecfut9x7zJyodWWP43YQ \
    --only-known-rpc \
   	--dynamic-port-range 8000-8025\
    --log $LOG_FILE \
    --ledger $LEDGER \
    --accounts $ACCOUNTS \
    --snapshots $SNAPSHOTS \
    --minimal-snapshot-download-speed 10485760 \
    --private-rpc \
    --no-snapshot-fetch \
    --rpc-port 8899 \
    --entrypoint entrypoint.testnet.solana.com:8001 \
    --entrypoint entrypoint2.testnet.solana.com:8001 \
    --entrypoint entrypoint3.testnet.solana.com:8001 \
    --tip-payment-program-pubkey $TIP_PROGRAM_PUBKEY \
          --tip-distribution-program-pubkey $TIP_DISTRIBUTION_PROGRAM_PUBKEY \
          --merkle-root-upload-authority $MERKLE_ROOT_UPLOAD_AUTHORITY \
	  --commission-bps 10000 \
	   --block-engine-url $JITO_BLOCK_ENGINE_URL \
--shred-receiver-address  $JITO_SHRED_RECEIVER_ADDRESS \
--expected-shred-version 9065 \
--expected-bank-hash 4oMrSXsLTiCc1X7S27kxSfGVraTCZoZ7YTy2skEB9bPk \
    --wal-recovery-mode skip_any_corrupted_record \
    --limit-ledger-size
