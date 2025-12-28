#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGLIST="$SCRIPT_DIR/pkglist.txt"

if [ ! -f "$PKGLIST" ]; then
    echo "Error: Package list not found at $PKGLIST"
    exit 1
fi

echo "==========================================================="
echo "   📦 Installing Packages from pkglist.txt"
echo "==========================================================="

# Check for AUR helpers
if command -v yay > /dev/null; then
    PACMAN_CMD="yay -S --needed --noconfirm"
    echo "   Using: yay"
elif command -v paru > /dev/null; then
    PACMAN_CMD="paru -S --needed --noconfirm"
    echo "   Using: paru"
else
    echo "   ⚠️ AUR helper (yay/paru) not found. Using pacman."
    echo "   Some packages might fail if they are in AUR."
    PACMAN_CMD="sudo pacman -S --needed --noconfirm"
fi

# Install loop
echo "   Reading package list..."
grep -vE '^\s*#|^\s*$' "$PKGLIST" | xargs $PACMAN_CMD

echo "   ✅ Package installation process finished."