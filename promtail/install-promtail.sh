#!/bin/bash

set -e

echo "Installing Promtail..."

sudo apt install -y unzip

CONFIG_PATH="$(pwd)/config.yml"

curl -O -L "https://github.com/grafana/loki/releases/download/v3.0.0/promtail-linux-amd64.zip"
unzip -o promtail-linux-amd64.zip
chmod +x promtail-linux-amd64
sudo mv promtail-linux-amd64 /usr/local/bin/promtail

sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail
sudo chown ubuntu:ubuntu /var/lib/promtail

sudo cp "$CONFIG_PATH" /etc/promtail/config.yml

sudo tee /etc/systemd/system/promtail.service > /dev/null <<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

FILE_SIZE=$(stat -c%s /mnt/others/logs/solana-rpc.log)
echo "{\"positions\":{\"/mnt/others/logs/solana-rpc.log\":$FILE_SIZE}}" | sudo tee /var/lib/promtail/positions.yaml > /dev/null
sudo chown ubuntu:ubuntu /var/lib/promtail/positions.yaml

sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail

echo "Promtail installed and started"

promtail --version