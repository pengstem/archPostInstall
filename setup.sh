#!/bin/bash

# =============================================================================
# Arch Post-Install: Dotfiles Setup Script
# =============================================================================

set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
    echo "Please run this script as a regular user with sudo privileges."
    exit 1
fi

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
        if [ -L "$dest" ]; then
            local resolved_dest
            resolved_dest="$(readlink -f "$dest" 2>/dev/null || true)"
            if [ "$resolved_dest" == "$src" ]; then
                echo "✅ Already linked"
                return
            fi
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
        if sudo test -L "$dest"; then
            local resolved_dest
            resolved_dest="$(sudo readlink -f "$dest" 2>/dev/null || true)"
            if [ "$resolved_dest" == "$src" ]; then
                echo "✅ Already linked"
                return
            fi
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
create_sudo_link "$CONFIGS_DIR/pacman/hooks/99-update-pkglist.hook" "/etc/pacman.d/hooks/99-update-pkglist.hook" "Pkglist Hook"
create_sudo_link "$REPO_DIR/scripts/update_pkglist.sh" "/usr/local/bin/archpostinstall-update-pkglist" "Pkglist Sync"

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
create_link "$CONFIGS_DIR/rime"             "$HOME/.local/share/fcitx5/rime" "Fcitx5 Rime"

# Applications
create_link "$CONFIGS_DIR/applications/QQ.desktop"     "$HOME/.local/share/applications/QQ.desktop"     "QQ"
create_link "$CONFIGS_DIR/applications/WeChat.desktop" "$HOME/.local/share/applications/WeChat.desktop" "WeChat"

# Bin (User)
create_link "$REPO_DIR/scripts/gnome/backup_gnome_state.sh" "$HOME/.local/bin/archpostinstall-gnome-sync" "Gnome Sync Bin"
create_link "$REPO_DIR/scripts/archpostinstall.sh" "$HOME/.local/bin/archpostinstall" "Archpostinstall Bin"

# Systemd (User)
create_link "$CONFIGS_DIR/systemd/user/archpostinstall-gnome-sync.service" "$HOME/.config/systemd/user/archpostinstall-gnome-sync.service" "Gnome Sync Service"
create_link "$CONFIGS_DIR/systemd/user/archpostinstall-gnome-sync.path"    "$HOME/.config/systemd/user/archpostinstall-gnome-sync.path"    "Gnome Sync Path"

echo ""
echo "✨ Configuration linking complete!"
