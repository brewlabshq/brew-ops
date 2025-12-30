#!/bin/bash

set -e

echo "Installing fail2ban..."
sudo apt install -y fail2ban

echo "Enabling and starting fail2ban service..."
sudo systemctl enable --now fail2ban

echo "Waiting for service to start..."
sleep 2

echo "Configuring sshd jail..."
sudo mkdir -p /etc/fail2ban/jail.d

cat <<EOF | sudo tee /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
mode = aggressive
port = ssh
backend = systemd
bantime = 1h
findtime = 10m
maxretry = 5
EOF

echo "Restarting fail2ban service..."
sudo systemctl restart fail2ban

echo "Waiting for service to restart..."
sleep 2

echo "Fail2ban status:"
systemctl status fail2ban --no-pager

echo ""
echo "Jail status:"
sudo fail2ban-client status

echo ""
echo "SSHD jail details:"
sudo fail2ban-client status sshd

echo ""
echo "Installation complete!"

