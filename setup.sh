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

# --- Link Configurations ---

# Shell
create_link "$CONFIGS_DIR/zshrc"            "$HOME/.zshrc"                  "Zshrc"

# Terminals
create_link "$CONFIGS_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" "Kitty"
create_link "$CONFIGS_DIR/ghostty"          "$HOME/.config/ghostty"         "Ghostty"

# Editors
create_link "$CONFIGS_DIR/nvim"             "$HOME/.config/nvim"            "Neovim"
create_link "$CONFIGS_DIR/zed"              "$HOME/.config/zed"             "Zed"

# Tools
create_link "$CONFIGS_DIR/tmux"             "$HOME/.config/tmux"            "Tmux"
create_link "$CONFIGS_DIR/fcitx5"           "$HOME/.config/fcitx5"          "Fcitx5"

echo ""
echo "✨ Configuration linking complete!"