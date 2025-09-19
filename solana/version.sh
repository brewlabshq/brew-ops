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

TAG="${1:-}"
[[ -n "$TAG" ]] || die "Usage: $0 <git-tag> (e.g., v1.18.22-jito)"

info "Cloning or updating jito-solana for tag: $TAG"

# Run the whole flow as user 'sol'
sudo -u sol -H TAG="$TAG" bash -lc '
  set -euo pipefail
  REPO_URL="https://github.com/jito-foundation/jito-solana.git"
  REPO_DIR="$HOME/jito-solana"
  INSTALL_ROOT="$HOME/.local/share/solana/install"
  RELEASE_DIR="$INSTALL_ROOT/releases/$TAG"

  # Ensure base dirs exist
  mkdir -p "$INSTALL_ROOT/releases"

  if [[ ! -d "$REPO_DIR" ]]; then
    echo "Cloning repo..."
    git clone "$REPO_URL" --recurse-submodules "$REPO_DIR"
  fi

  cd "$REPO_DIR"
  # Ensure we have all tags locally
  git fetch --tags --prune
  git submodule update --init --recursive

  # Verify tag exists
  if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Tag not found: $TAG" >&2
    exit 1
  fi

  echo "Checking out tag $TAG..."
  git checkout "tags/$TAG"

  # Prepare release directory
  mkdir -p "$RELEASE_DIR"

  # Build & install validator-only binaries into the release dir
  echo "Building and installing to: $RELEASE_DIR"
  CI_COMMIT="$(git rev-parse HEAD)" scripts/cargo-install-all.sh --validator-only "$RELEASE_DIR"

  # Point active_release -> releases/$TAG (so PATH .../active_release/bin works)
  ln -sfn "$RELEASE_DIR" "$INSTALL_ROOT/active_release"

  echo "Active release now points to: $INSTALL_ROOT/active_release -> $RELEASE_DIR"
'

ok "jito-solana $TAG installed. PATH should include ~/.local/share/solana/install/active_release/bin"
echo "Tip: for user 'sol', ensure ~/.bashrc exports:"
echo '  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
