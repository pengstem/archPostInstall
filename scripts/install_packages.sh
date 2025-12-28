#!/bin/bash

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGLIST="$SCRIPT_DIR/pkglist.txt"

if [ ! -f "$PKGLIST" ]; then
    echo "Error: Package list not found at $PKGLIST"
    exit 1
fi

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
    
    git clone https://aur.archlinux.org/paru-bin.git "$tmp_dir/paru-bin"
    
    pushd "$tmp_dir/paru-bin" > /dev/null
    makepkg -si --noconfirm
    popd > /dev/null
    
    rm -rf "$tmp_dir"
    echo "   ✅ paru installed."
}

# Check for AUR helpers
if command -v paru > /dev/null; then
    PACMAN_CMD="paru -S --needed --noconfirm"
    echo "   Using: paru (Already installed)"
elif command -v yay > /dev/null; then
    PACMAN_CMD="yay -S --needed --noconfirm"
    echo "   Using: yay"
else
    echo "   ⚠️ No AUR helper found. Installing paru..."
    install_paru
    PACMAN_CMD="paru -S --needed --noconfirm"
fi

# Install packages
echo "   Reading package list from $PKGLIST..."
# Filter out comments and empty lines
PACKAGES=$(grep -vE '^\s*#|^\s*$' "$PKGLIST")

if [ -n "$PACKAGES" ]; then
    # We use echo to pass the list to xargs or run directly. 
    # Passing directly to paru is better to handle dependencies in one go.
    echo "$PACKAGES" | xargs $PACMAN_CMD
else
    echo "   Package list is empty."
fi

echo "   ✅ Package installation process finished."
