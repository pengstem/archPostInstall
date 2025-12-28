#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Define repo root
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==========================================================="
echo "   🚀 Starting Arch Linux Post-Install Setup"
echo "==========================================================="
echo " This script will:"
echo " 1. Install system packages (from pkglist.txt)"
echo " 2. Setup Shell (Oh My Zsh, plugins, tools)"
echo " 3. Symlink configuration files (Dotfiles)"
echo "==========================================================="
echo ""

# Request sudo upfront to clear the timeout
echo "🔒 Requesting sudo privileges for package installation..."
sudo -v
# Keep-alive: update existing `sudo` time stamp until finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo ""
echo "📦 [1/3] Installing System Packages..."
"$REPO_DIR/scripts/install_packages.sh"

echo ""
echo "gw [2/3] Setting up Shell & Tools..."
"$REPO_DIR/scripts/install_shell_tools.sh"

echo ""
echo "🔗 [3/3] Linking Dotfiles..."
"$REPO_DIR/setup.sh"

echo ""
echo "🐚 Changing default shell to Zsh..."
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
    echo "   Default shell changed to Zsh."
else
    echo "   Zsh is already the default shell."
fi

echo ""
echo "==========================================================="
echo "   🎉 Setup Complete! Please restart your computer."
echo "==========================================================="
