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
TIP_PROGRAM_PUBKEY=T1pyyaTNZsKv2WcRAB8oVnk93mLJw2XzjtVYqCsaHqt
TIP_DISTRIBUTION_PROGRAM_PUBKEY=4R3gSG8BpU4t19KYj8CfnbtRpnT8gtk4dvTHxVRwc2r7
MERKLE_ROOT_UPLOAD_AUTHORITY=GZctHpWXmsZC1YHACTGGcHhYxjdRqQvTpYkb9LMvxDib
JITO_COMMISION_BPS=0
JITO_SHRED_RECEIVER_ADDRESS=64.130.50.14:1002
JITO_BLOCK_ENGINE_URL=https://frankfurt.mainnet.block-engine.jito.wtf


if [[ -d /mnt/ledger/snapshot-store ]]; then
    SNAPSHOT=mnt/ledger/snapshot-store
else
	SNAPSHOT=/mnt/snapshot
fi

exec  /home/sol/.local/share/solana/install/active_release/bin/agave-validator \
--identity $IDENTITY_FILE \
--vote-account $VOTE_ACCOUNT \
--authorized-voter $AUTHORIZED_VOTER \
--only-known-rpc \
--log $LOG_FILE \
--ledger $LEDGER \
--accounts $ACCOUNTS \
--snapshots $SNAPSHOT \
--rpc-port 8899 \
--limit-ledger-size \
--private-rpc \
--tip-payment-program-pubkey $TIP_PROGRAM_PUBKEY \
--tip-distribution-program-pubkey $TIP_DISTRIBUTION_PROGRAM_PUBKEY \
--merkle-root-upload-authority $MERKLE_ROOT_UPLOAD_AUTHORITY \
--known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
--known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
--known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
--known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
--known-validator J2jV3gQsvX2htBXHeNStAVvMJaPe3RgNotwfav9pyS6y \
--known-validator 4QNekaDqrLmUENqkVhGCJrgHziPxkX9kridbKwunx9su \
--commission-bps $JITO_COMMISION_BPS \
--shred-receiver-address $JITO_SHRED_RECEIVER_ADDRESS  \
--block-engine-url $JITO_BLOCK_ENGINE_URL \
--entrypoint entrypoint.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
--incremental-snapshot-interval-slots 0 \
--minimal-snapshot-download-speed 10485760 \
--block-production-method central-scheduler-greedy
