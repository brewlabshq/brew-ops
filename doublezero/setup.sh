#!/bin/bash

set -eou pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root or with sudo"
fi

# Check if sol user exists
if ! id -u sol >/dev/null 2>&1; then
    die "User 'sol' not found. Please create the sol user first."
fi

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v apt-get &> /dev/null; then
        missing_deps+=("apt-get")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        die "Missing required dependencies: ${missing_deps[*]}. Please install them before running this script."
    fi
}

# Check if doublezero is already installed
check_existing_installation() {
    if command -v doublezero &> /dev/null; then
        local current_version=$(doublezero --version 2>/dev/null || echo "unknown")
        warn "Doublezero is already installed (version: $current_version)"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Skipping installation, proceeding with configuration..."
            return 0
        fi
    fi
    return 1
}

info "Setting up Doublezero for Solana validator monitoring..."

# Check dependencies
info "Checking dependencies..."
check_dependencies
ok "All dependencies found"

# Check existing installation
if ! check_existing_installation; then
    # Install doublezero
    info "Installing Doublezero repository..."
    curl -1sLf https://dl.cloudsmith.io/public/malbeclabs/doublezero/setup.deb.sh | sudo -E bash
    
    info "Installing Doublezero version 0.6.6..."
    apt-get update
    apt-get install -y doublezero=0.6.6-1
    ok "Doublezero installed successfully"
fi

# Create configuration directory for sol user
info "Setting up configuration directory..."
sudo -u sol mkdir -p /home/sol/.config/doublezero
ok "Configuration directory created"

# Generate keypair for sol user
info "Generating Doublezero keypair for sol user..."
sudo -u sol doublezero keygen
ok "Keypair generated"

# Display address
info "Doublezero address:"
sudo -u sol doublezero address

# Test latency
info "Testing network latency..."
sudo -u sol doublezero latency

ok "Doublezero setup completed successfully!"
info ""
info "Doublezero is now ready for monitoring your Solana validator."
info "Configuration files are located in: /home/sol/.config/doublezero/"
info ""
info "Useful commands:"
info "  sudo -u sol doublezero address    # Show your doublezero address"
info "  sudo -u sol doublezero latency    # Test network latency"
info "  sudo -u sol doublezero --help     # Show all available commands" 