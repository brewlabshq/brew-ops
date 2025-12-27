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

# Parse arguments
CLIENT="${1:-}"
TAG="${2:-}"

# Validate client
if [[ -z "$CLIENT" ]]; then
    die "Usage: $0 <client> <git-tag>
  Clients: jito, bam
  Example: $0 jito v1.18.22-jito
  Example: $0 bam v3.0.12-bam"
fi

# Set repository details based on client
case "$CLIENT" in
    jito)
        REPO_URL="https://github.com/jito-foundation/jito-solana.git"
        REPO_DIR="/home/sol/jito-solana"
        CLIENT_NAME="jito-solana"
        ;;
    bam)
        REPO_URL="https://github.com/jito-labs/bam-client.git"
        REPO_DIR="/home/sol/bam-client"
        CLIENT_NAME="bam-client"
        ;;
    *)
        die "Invalid client: $CLIENT. Valid options: jito, bam"
        ;;
esac

# Validate tag
[[ -n "$TAG" ]] || die "Usage: $0 $CLIENT <git-tag> (e.g., $0 $CLIENT v1.18.22-jito or $0 $CLIENT v3.0.12-bam)"

info "Cloning or updating $CLIENT_NAME for tag: $TAG"

# Run the whole flow as user 'sol'
sudo -u sol -H CLIENT="$CLIENT" REPO_URL="$REPO_URL" REPO_DIR="$REPO_DIR" CLIENT_NAME="$CLIENT_NAME" TAG="$TAG" bash -lc '
  set -euo pipefail
  INSTALL_ROOT="$HOME/.local/share/solana/install"
  RELEASE_DIR="$INSTALL_ROOT/releases/$TAG"

  # Ensure base dirs exist
  mkdir -p "$INSTALL_ROOT/releases"

  if [[ ! -d "$REPO_DIR" ]]; then
    echo "Cloning $CLIENT_NAME repo..."
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

  echo "Updating submodules..."
  git submodule update --init --recursive

  # Prepare release directory
  mkdir -p "$RELEASE_DIR"

  # Build & install validator-only binaries into the release dir
  echo "Building and installing to: $RELEASE_DIR"
  CI_COMMIT="$(git rev-parse HEAD)" scripts/cargo-install-all.sh --validator-only "$RELEASE_DIR"

 

  echo "Active release now points to: $RELEASE_DIR"
'

ok "$CLIENT_NAME $TAG installed. PATH should include ~/.local/share/solana/install/active_release/bin"
echo "Tip: for user 'sol', ensure ~/.bashrc exports:"
echo '  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
