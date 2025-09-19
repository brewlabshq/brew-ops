#!/bin/bash

set -euo pipefail

die() { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }


require_root() {
  if [[ $EUID -ne 0 ]]; then
    die "Run as root (use sudo)."
  fi
}

check_block() {
  local dev="$1"
  [[ -b "$dev" ]] || die "Block device not found: $dev"
}

is_mounted() {
  local mp="$1"
  mountpoint -q "$mp"
}

ensure_dir() {
  local d="$1"
  mkdir -p "$d"
}

get_uuid() {
  local dev="$1"
  blkid -s UUID -o value "$dev"
}

append_fstab_if_missing() {
  local uuid="$1" fstype="$2" mnt="$3" opts="$4"
  local pattern="UUID=$uuid $mnt $fstype"
  if ! grep -qsE "^UUID=$uuid[[:space:]]+$mnt[[:space:]]+$fstype" /etc/fstab; then
    echo "UUID=$uuid $mnt $fstype $opts 0 2" >> /etc/fstab
    ok "Added to /etc/fstab: $pattern ($opts)"
  else
    warn "/etc/fstab already contains: $pattern"
  fi
}

format_xfs() {
  local dev="$1"
  if blkid "$dev" &>/dev/null; then
    warn "$dev already has a filesystem; skipping mkfs.xfs (use wipefs if intentional)."
  else
    info "Formatting $dev as XFS..."
    mkfs.xfs -f "$dev" >/dev/null
    ok "Formatted $dev (XFS)."
  fi
}

format_ext4() {
  local dev="$1"
  if blkid "$dev" &>/dev/null; then
    warn "$dev already has a filesystem; skipping mkfs.ext4."
  else
    info "Formatting $dev as EXT4..."
    mkfs.ext4 -F "$dev" >/dev/null
    ok "Formatted $dev (EXT4)."
  fi
}

require_root

if [[ $# -lt 2 ]]; then
  cat >&2 <<USAGE
Usage:
  $0 <count: 2|3> <ledger_dev> <account_dev> [snapshot_dev]

Examples:
  $0 3 /dev/nvme2n1 /dev/nvme0n1 /dev/nvme1n1
  $0 2 /dev/nvme2n1 /dev/nvme0n1
USAGE
  exit 1
fi




# if [[ "$COUNT" == "3" ]]; then
# 	echo -e "✅ Create 3 disk config:\n"
#     echo "  Ledger:     /mnt/ledger"
#     echo "  Accounts:   /mnt/account"
#     echo "  Snapshots:  /mnt/snapshot"

# elif [[ "$COUNT" == "2" ]]; then
# 	echo -e "✅ Create 2 disk config:\n"
#     echo "  Ledger:     /mnt/ledger"
#     echo "  Accounts:   /mnt/account"
#     echo "  Snapshots:  /mnt/ledger/snapshot-store"
# else
#     echo "Count is not 3 or 2, no disk config detected"
#     exit 1
# fi

COUNT="$1"; shift
LEDGER_DEV="${1:-}"; shift || true
ACCOUNT_DEV="${1:-}"; shift || true
SNAPSHOT_DEV="${1:-}"; shift || true

[[ "$COUNT" == "2" || "$COUNT" == "3" ]] || die "COUNT must be 2 or 3."
[[ -n "$LEDGER_DEV" && -n "$ACCOUNT_DEV" ]] || die "Missing device arguments."


# --- Mount points ---
LEDGER_MNT="/mnt/ledger"
ACCOUNT_MNT="/mnt/account"
if [[ "$COUNT" == "3" ]]; then
  SNAPSHOT_MNT="/mnt/snapshot"
else
  SNAPSHOT_MNT="/mnt/ledger/snapshot-store"
fi


# --- Mount with options ---
# Ledger: XFS with noatime + logbufs=8 (as in your example)
# mount_with_opts "$LEDGER_DEV" "$LEDGER_MNT" "xfs" "defaults,noatime,logbufs=8"
