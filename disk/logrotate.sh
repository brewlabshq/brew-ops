#!/bin/bash

set -e

cat > logrotate.sol <<EOF
/home/sol/logs/solana-validator.log {
    rotate 7
    daily
    missingok
    postrotate
        systemctl kill -s USR1 sol.service
    endscript
}
EOF

sudo cp logrotate.sol /etc/logrotate.d/sol
systemctl restart logrotate.service
