#!/bin/bash

set -eou

die() { echo "❌ $*" >&2; exit 1; }
info(){ echo "➡️  $*"; }
ok(){ echo "✅ $*"; }
warn(){ echo "⚠️  $*"; }

[[ $EUID -eq 0 ]] || die "Run as root (use sudo)."

su - sol

echo "Installing Rust..."
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env
rustup component add rustfmt
rustup update


echo "Installing Solana..."

git clone https://github.com/jito-foundation/jito-solana.git --recurse-submodules

BASHRC="/home/sol/.bashrc"
BACKUP="/home/sol/.bashrc.$(date +%Y%m%d-%H%M%S).bak"

cp -a "$BASHRC" "$BACKUP"


if ! sudo grep -Fq '>>> solana env & aliases >>>' "$BASHRC"; then
  sudo tee -a "$BASHRC" >/dev/null <<'EOF'
# >>> solana env & aliases >>>
export PATH="/home/sol/.local/share/solana/install/active_release/bin:$PATH"

# Helpful Aliases
alias catchup='solana catchup --our-localhost'
alias monitor='agave-validator --ledger /mnt/ledger monitor'
alias logtail='tail -f /home/sol/logs/solana-validator.log'
# <<< solana env & aliases <<<
EOF
  sudo chown sol:sol "$BASHRC"
  echo "✅ Appended block. Backup saved at: $BACKUP"
else
  echo "⚠️  Block already present; nothing appended."
fi

# Reload for user 'sol' (won't affect current shell)
sudo -u sol bash -lc 'source ~/.bashrc'
