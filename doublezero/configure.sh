#!/bin/bash

set -eou pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# Default environment
DEFAULT_ENV="mainnet-beta"

# Check if environment is provided as argument
if [ $# -eq 0 ]; then
    warn "No environment specified, using default: $DEFAULT_ENV"
    DESIRED_DOUBLEZERO_ENV="$DEFAULT_ENV"
else
    DESIRED_DOUBLEZERO_ENV="$1"
fi

# Validate environment
case "$DESIRED_DOUBLEZERO_ENV" in
    mainnet-beta|testnet)
        info "Using environment: $DESIRED_DOUBLEZERO_ENV"
        ;;
    *)
        die "Invalid environment: $DESIRED_DOUBLEZERO_ENV. Valid options: mainnet-beta, testnet, devnet"
        ;;
esac

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root or with sudo"
fi

# Check if doublezero is installed
if ! command -v doublezero &> /dev/null; then
    die "Doublezero is not installed. Please run the setup script first."
fi

# Check if doublezerod service exists
if ! systemctl list-unit-files | grep -q "doublezerod.service"; then
    die "Doublezerod service not found. Please ensure doublezero is properly installed."
fi

info "Configuring Doublezero for environment: $DESIRED_DOUBLEZERO_ENV"

# Create systemd override directory
info "Creating systemd override directory..."
mkdir -p /etc/systemd/system/doublezerod.service.d

# Create systemd override configuration
info "Creating systemd override configuration..."
cat > /etc/systemd/system/doublezerod.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/doublezerod -sock-file /run/doublezerod/doublezerod.sock -env $DESIRED_DOUBLEZERO_ENV
EOF

# Reload systemd daemon
info "Reloading systemd daemon..."
systemctl daemon-reload

# Restart doublezerod service
info "Restarting doublezerod service..."
systemctl restart doublezerod

# Wait a moment for service to start
sleep 2

# Check if service is running
if systemctl is-active --quiet doublezerod; then
    ok "Doublezerod service is running"
else
    warn "Doublezerod service may not be running properly"
    systemctl status doublezerod --no-pager -l
fi

# Configure doublezero client
info "Configuring doublezero client..."
sudo -u sol doublezero config set --env "$DESIRED_DOUBLEZERO_ENV" || {
    warn "Failed to set doublezero config for sol user, trying as root..."
    doublezero config set --env "$DESIRED_DOUBLEZERO_ENV"
}

ok "Doublezero configured successfully for environment: $DESIRED_DOUBLEZERO_ENV"

# Test latency
info "Testing network latency..."
sudo -u sol doublezero latency || {
    warn "Failed to test latency as sol user, trying as root..."
    doublezero latency
}

info ""
info "Configuration complete!"
info "Environment: $DESIRED_DOUBLEZERO_ENV"
info "Service status: $(systemctl is-active doublezerod)"
info ""
info "Useful commands:"
info "  sudo systemctl status doublezerod    # Check service status"
info "  sudo systemctl restart doublezerod   # Restart service"
info "  sudo -u sol doublezero latency       # Test latency"
info "  sudo -u sol doublezero address       # Show address"