#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PKGLIST="$REPO_DIR/scripts/pkglist.txt"

if [ ! -f "$PKGLIST" ]; then
  echo "Error: Package list not found at $PKGLIST"
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command not found: $1"
    exit 1
  fi
}

require_cmd sudo
require_cmd pacman

echo "==========================================================="
echo "   📦 Installing Packages"
echo "==========================================================="

install_paru() {
  echo "   🔧 Installing 'paru' (AUR helper)..."

  # Ensure base-devel and git are installed
  sudo pacman -S --needed --noconfirm base-devel git

  # Create temporary directory
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' RETURN

  git clone https://aur.archlinux.org/paru-bin.git "$tmp_dir/paru-bin"

  pushd "$tmp_dir/paru-bin" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null

  echo "   ✅ paru installed."
}

# Check for AUR helpers
if command -v paru >/dev/null; then
  PACMAN_CMD=(paru -S --needed --noconfirm)
  echo "   Using: paru (Already installed)"
elif command -v yay >/dev/null; then
  PACMAN_CMD=(yay -S --needed --noconfirm)
  echo "   Using: yay"
else
  echo "   ⚠️ No AUR helper found. Installing paru..."
  install_paru
  PACMAN_CMD=(paru -S --needed --noconfirm)
fi

# Install packages
echo "   Reading package list from $PKGLIST..."
# Filter out comments and empty lines
mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "$PKGLIST" || true)

if ((${#PACKAGES[@]})); then
  # Passing directly to the helper is better for dependency resolution.
  "${PACMAN_CMD[@]}" "${PACKAGES[@]}"
else
  echo "   Package list is empty."
fi

echo "   ✅ Package installation process finished."
