#!/bin/bash

echo "Disabling automatic updates..."
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades
sudo systemctl mask unattended-upgrades

sudo systemctl stop apt-daily.timer
sudo systemctl disable apt-daily.timer

sudo systemctl stop apt-daily-upgrade.timer
sudo systemctl disable apt-daily-upgrade.timer

echo "✅ Automatic updates disabled. You now have full control over system updates."

# Manual system update
echo "Running manual system update..."
sudo apt upgrade -y

# Install required dependencies
echo "Installing system dependencies..."
sudo apt-get install -y libssl-dev libudev-dev pkg-config zlib1g-dev llvm clang cmake make libprotobuf-dev protobuf-compiler libclang-dev

echo "✅ System setup complete!"
