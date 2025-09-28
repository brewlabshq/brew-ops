#!/bin/bash

set -eou pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/home/sol/scripts"

info "Setting up hotswap scripts for sol user..."
info "Source directory: $SCRIPT_DIR"
info "Target directory: $TARGET_DIR"

# Check if we're running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root or with sudo to copy files to /home/sol/scripts"
fi

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    info "Creating directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
else
    info "Directory already exists: $TARGET_DIR"
fi

# Copy the hotswap scripts
info "Copying hotswap scripts..."

# Copy example.identity-set.sh as identity-set
if [ -f "$SCRIPT_DIR/example.identity-set.sh" ]; then
    cp "$SCRIPT_DIR/example.identity-set.sh" "$TARGET_DIR/identity-set.sh"
    chmod +x "$TARGET_DIR/identity-set.sh"
    chown sol:sol "$TARGET_DIR/identity-set.sh"
    ok "Copied example.identity-set.sh as identity-set.sh"
else
    warn "example.identity-set.sh not found in source directory"
fi

# Copy example.migration.sh as migration
if [ -f "$SCRIPT_DIR/example.migration.sh" ]; then
    cp "$SCRIPT_DIR/example.migration.sh" "$TARGET_DIR/migration.sh"
    chmod +x "$TARGET_DIR/migration.sh"
    chown sol:sol "$TARGET_DIR/migration.sh"
    ok "Copied example.migration.sh as migration.sh"
else
    warn "example.migration.sh not found in source directory"
fi

# Copy example.identity-set-no-tower.sh as identity-set-no-tower
if [ -f "$SCRIPT_DIR/example.identity-set-no-tower.sh" ]; then
    cp "$SCRIPT_DIR/example.identity-set-no-tower.sh" "$TARGET_DIR/identity-set-no-tower.sh"
    chmod +x "$TARGET_DIR/identity-set-no-tower.sh"
    chown sol:sol "$TARGET_DIR/identity-set-no-tower.sh"
    ok "Copied example.identity-set-no-tower.sh as identity-set-no-tower.sh"
else
    warn "example.identity-set-no-tower.sh not found in source directory"
fi

# Set proper ownership and permissions for the scripts directory
chown -R sol:sol "$TARGET_DIR"
chmod 755 "$TARGET_DIR"

ok "Setup completed successfully!"
info "Scripts are now available in $TARGET_DIR and can be run by the sol user"
info ""
info "Usage examples:"
info "  sudo -u sol $TARGET_DIR/identity-set.sh /path/to/identity.json"
info "  sudo -u sol $TARGET_DIR/identity-set-no-tower.sh /path/to/identity.json"
info "  sudo -u sol $TARGET_DIR/migration.sh user@hostname /path/to/identity.json"
