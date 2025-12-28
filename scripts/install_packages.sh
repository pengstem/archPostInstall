#!/bin/bash

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGLIST="$REPO_DIR/pkglist.txt"

if [ ! -f "$PKGLIST" ]; then
    echo "Package list not found at $PKGLIST"
    exit 1
fi

echo "Installing packages from $PKGLIST..."

# Check for yay or paru, fallback to pacman
if command -v yay > /dev/null; then
    PACMAN_CMD="yay -S --needed"
elif command -v paru > /dev/null; then
    PACMAN_CMD="paru -S --needed"
else
    echo "AUR helper not found, using pacman (some packages might fail if they are AUR only)."
    PACMAN_CMD="sudo pacman -S --needed"
fi

# Read lines, ignore comments and empty lines
grep -vE '^\s*#|^\s*$' "$PKGLIST" | xargs $PACMAN_CMD

echo "Package installation complete."
