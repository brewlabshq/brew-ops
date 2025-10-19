#!/bin/bash

set -eou pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# Default log file path
DEFAULT_LOG_PATH="/home/sol/logs/solana-validator.log"

# Check if log file path is provided as argument
if [ $# -eq 0 ]; then
    warn "No log file path provided, using default: $DEFAULT_LOG_PATH"
    LOG_FILE="$DEFAULT_LOG_PATH"
else
    LOG_FILE="$1"
fi

# Validate log file path
if [ -z "$LOG_FILE" ]; then
    die "Log file path cannot be empty"
fi

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root or with sudo"
fi

info "Setting up logrotate for: $LOG_FILE"

# Create logrotate configuration
info "Creating logrotate configuration..."
cat > logrotate.sol <<EOF
$LOG_FILE {
    rotate 5
    daily
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        systemctl kill -s USR1 sol.service
    endscript
}
EOF

# Copy configuration to logrotate directory
info "Installing logrotate configuration..."
cp logrotate.sol /etc/logrotate.d/sol
chmod 644 /etc/logrotate.d/sol

# Clean up temporary file
rm -f logrotate.sol

# Test logrotate configuration
info "Testing logrotate configuration..."
logrotate -d /etc/logrotate.d/sol

# Restart logrotate service
info "Restarting logrotate service..."
systemctl restart logrotate.service

ok "Logrotate setup completed successfully!"
info "Log file: $LOG_FILE"
info "Configuration: /etc/logrotate.d/sol"
info ""
info "The log file will be rotated daily, keeping 7 days of history."
info "Logs will be compressed after rotation."
