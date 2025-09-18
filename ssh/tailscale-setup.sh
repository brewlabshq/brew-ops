#!/bin/bash

set -euo pipefail

curl -fsSL https://tailscale.com/install.sh | sh

sudo systemctl start tailscaled
