#!/bin/bash

set -e


# Check if count is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <agave|firedancer>"
    exit 1
fi




open_ports() {
    echo "Opening ports..."
    if [[ $1 == "agave" ]]; then
        # Add your port opening logic for agave here
        echo "Opening ports for agave 8000-8025"
        ufw allow 8000:8025/tcp
        ufw allow 8000:8025/udp
        ufw reload
    elif [[ $1 == "firedancer" ]]; then
        # Add your port opening logic for firedancer here
        echo "Opening ports for firedancer 8900-9000 & 8001"
        ufw allow 8900:9000/tcp
        ufw allow 8900:9000/udp
        ufw allow 8001
        ufw reload
    else
        echo "Invalid option: $1"
        exit 1
    fi
}

open_ports
