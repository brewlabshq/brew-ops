#!/bin/bash

set -eou pipefail


die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (use sudo)."

info "Installing telegraf from influx db"
curl --silent --location -O https://repos.influxdata.com/influxdata-archive.key
gpg --show-keys --with-fingerprint --with-colons ./influxdata-archive.key 2>&1 \
| grep -q '^fpr:\+24C975CBA61A024EE1B631787C3D57159FC2F927:$' \
&& cat influxdata-archive.key \
| gpg --dearmor \
| sudo tee /etc/apt/keyrings/influxdata-archive.gpg > /dev/null \
&& echo 'deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' \
| sudo tee /etc/apt/sources.list.d/influxdata.list

sudo apt-get update && sudo apt-get install telegraf
info "Backuping telegraf configuration"
sudo cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.bak


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "Copying example telegraf configuration"
cp "$SCRIPT_DIR/example.telegraf.conf" /etc/telegraf/telegraf.conf

ok "Telegraf configuration copied"
warn "Update the telegraf configuration key"
