#!/bin/bash

# =============================================================================
# Arch Linux Post-Install Bootstrap
# =============================================================================

set -e  # Exit on error

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_header() {
    echo -e "\n${BLUE}=========================================================== ${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}=========================================================== ${NC}\n"
}

log_info() {
    echo -e "${GREEN}➜ $1${NC}"
}

# --- Start ---

log_header "🚀 Starting Arch Linux Post-Install Setup"

echo "This script will configured your system:"
echo " 1. Install system packages"
echo " 2. Setup Shell environment"
echo " 3. Symlink configuration files"
echo ""

# Ensure scripts are executable
chmod +x "$SCRIPTS_DIR"/*.sh "$REPO_DIR/setup.sh"

# Request sudo upfront
log_info "Requesting sudo privileges..."
sudo -v
# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# 1. Packages
log_header "📦 [1/3] Installing System Packages"
"$SCRIPTS_DIR/install_packages.sh"

# 2. Shell
log_header "🐚 [2/3] Setting up Shell & Tools"
"$SCRIPTS_DIR/install_shell_tools.sh"

# 3. Dotfiles
log_header "🔗 [3/3] Linking Dotfiles"
"$REPO_DIR/setup.sh"

# 4. Default Shell
log_header "⚙️  Finalizing"
if [ "$SHELL" != "$(which zsh)" ]; then
    log_info "Changing default shell to Zsh..."
    chsh -s "$(which zsh)"
else
    log_info "Zsh is already the default shell."
fi

echo ""
echo -e "${GREEN}✅ Setup Complete! Please restart your computer to apply all changes.${NC}"
echo ""