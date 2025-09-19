#!/usr/bin/env bash
set -euo pipefail

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (use sudo)."
id -u sol >/dev/null 2>&1 || die "User 'sol' not found."
command -v curl >/dev/null 2>&1 || die "curl is not installed."
command -v git  >/dev/null 2>&1 || die "git is not installed."

# -------------------------
# Install Rust for user 'sol'
# -------------------------
info "Installing Rust for user 'sol' (non-interactive)..."
sudo -u sol -H bash -lc '
  set -euo pipefail
  if ! command -v rustup >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
  fi
  # Ensure cargo env is loaded for this subshell
  if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
  fi
  rustup component add rustfmt || true
  rustup update
'
ok "Rust ready."

# -------------------------
# Get Solana (Jito fork)
# -------------------------
info "Cloning or updating jito-solana..."
sudo -u sol -H bash -lc '
  set -euo pipefail
  cd "$HOME"
  if [[ ! -d jito-solana ]]; then
    git clone https://github.com/jito-foundation/jito-solana.git --recurse-submodules
  else
    cd jito-solana
    git pull --ff-only
    git submodule update --init --recursive
  fi
'
ok "jito-solana ready."

# -------------------------
# Update /home/sol/.bashrc
# -------------------------
BASHRC="/home/sol/.bashrc"
BACKUP="/home/sol/.bashrc.$(date +%Y%m%d-%H%M%S).bak"

cp -a "$BASHRC" "$BACKUP"

if ! grep -Fq '>>> solana env & aliases >>>' "$BASHRC"; then
  cat >> "$BASHRC" <<'EOF'
# >>> solana env & aliases >>>
export PATH="/home/sol/.local/share/solana/install/active_release/bin:$PATH"

# Helpful Aliases
alias catchup='solana catchup --our-localhost'
alias monitor='agave-validator --ledger /mnt/ledger monitor'
alias logtail='tail -f /home/sol/logs/solana-validator.log'
# <<< solana env & aliases <<<
EOF
  chown sol:sol "$BASHRC"
  ok "Appended Solana env & aliases to $BASHRC (backup: $BACKUP)"
else
  warn "Block already present; nothing appended. (Backup: $BACKUP)"
fi

# Reload for user 'sol' (won't affect current shell)
sudo -u sol -H bash -lc 'source ~/.bashrc >/dev/null 2>&1 || true'

ok "All done."
