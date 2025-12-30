#!/bin/bash

# =============================================================================
# Arch Post-Install: Dotfiles Setup Script
# =============================================================================

set -e

# Define directories
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$REPO_DIR/configs"

echo "==========================================================="
echo "   🔗 Setting up Symbolic Links"
echo "==========================================================="

# Function to create symlink
create_link() {
    local src="$1"
    local dest="$2"
    local name="$3"

    printf "  %-15s " "[$name]"

    # Check source
    if [ ! -e "$src" ]; then
        echo "❌ Source not found: $src"
        return
    fi

    # Check existing destination
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # Check if already correctly linked
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" == "$src" ]; then
            echo "✅ Already linked"
            return
        fi

        # Backup
        echo -n "🔄 Backing up... "
        mv "$dest" "$dest.bak_$(date +%s)"
    fi

    # Ensure parent dir
    mkdir -p "$(dirname "$dest")"

    # Link
    ln -s "$src" "$dest"
    echo "✅ Linked"
}

# Function to create symlink with sudo (for /etc files)
create_sudo_link() {
    local src="$1"
    local dest="$2"
    local name="$3"

    printf "  %-15s " "[$name]"

    # Check source
    if [ ! -e "$src" ]; then
        echo "❌ Source not found: $src"
        return
    fi

    # Check existing destination
    if sudo test -e "$dest" || sudo test -L "$dest"; then
        # Check if already correctly linked
        if sudo test -L "$dest" && [ "$(sudo readlink -f "$dest")" == "$src" ]; then
            echo "✅ Already linked"
            return
        fi

        # Backup
        echo -n "🔄 Backing up... "
        sudo mv "$dest" "$dest.bak_$(date +%s)"
    fi

    # Ensure parent dir
    sudo mkdir -p "$(dirname "$dest")"

    # Link
    sudo ln -s "$src" "$dest"
    echo "✅ Linked (sudo)"
}

# --- Link Configurations ---

# System Configs (Requires Sudo)
create_sudo_link "$CONFIGS_DIR/pacman/pacman.conf" "/etc/pacman.conf" "Pacman"
create_sudo_link "$CONFIGS_DIR/paru/paru.conf"     "/etc/paru.conf"   "Paru"

# Shell
create_link "$CONFIGS_DIR/zshrc"            "$HOME/.zshrc"                  "Zshrc"
create_link "$CONFIGS_DIR/p10k.zsh"         "$HOME/.p10k.zsh"               "P10k Config"
create_link "$CONFIGS_DIR/gitconfig"        "$HOME/.gitconfig"              "Gitconfig"

# Terminals
create_link "$CONFIGS_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" "Kitty"
create_link "$CONFIGS_DIR/ghostty"          "$HOME/.config/ghostty"         "Ghostty"

# Editors
create_link "$CONFIGS_DIR/nvim"             "$HOME/.config/nvim"            "Neovim"
create_link "$CONFIGS_DIR/zed"              "$HOME/.config/zed"             "Zed"

# Tools
create_link "$CONFIGS_DIR/tmux"             "$HOME/.config/tmux"            "Tmux"
create_link "$CONFIGS_DIR/fcitx5"           "$HOME/.config/fcitx5"          "Fcitx5"

# Applications
create_link "$CONFIGS_DIR/applications/QQ.desktop"     "$HOME/.local/share/applications/QQ.desktop"     "QQ"
create_link "$CONFIGS_DIR/applications/WeChat.desktop" "$HOME/.local/share/applications/WeChat.desktop" "WeChat"

echo ""
echo "✨ Configuration linking complete!"