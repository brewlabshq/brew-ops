#!/bin/bash

# Script to add a user to the sudo group on Ubuntu

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

# Check if username is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"

# Check if user exists
if id "$USERNAME" &>/dev/null; then
    echo "✅ User '$USERNAME' exists"
else
    echo "❌ User '$USERNAME' does not exist. Creating..."
    adduser --gecos "" "$USERNAME"
fi

# Add user to sudo group
usermod -aG sudo "$USERNAME"
echo "🔑 User '$USERNAME' has been added to the sudo group"

# Show groups for verification
echo "📋 Groups for $USERNAME:"
groups "$USERNAME"

echo "✅ Done. Please log out and log back in as '$USERNAME' to use sudo."
