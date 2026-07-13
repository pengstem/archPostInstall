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

# Function to install sudoers files with correct permissions
install_sudoers() {
    local src="$1"
    local dest="$2"
    local name="$3"

    printf "  %-15s " "[$name]"

    if [ ! -e "$src" ]; then
        echo "❌ Source not found: $src"
        return
    fi

    sudo install -m 0440 -o root -g root "$src" "$dest"
    echo "✅ Installed"
}

# --- Link Configurations ---

# System Configs (Requires Sudo)
create_sudo_link "$CONFIGS_DIR/pacman/pacman.conf" "/etc/pacman.conf" "Pacman"
create_sudo_link "$CONFIGS_DIR/paru/paru.conf"     "/etc/paru.conf"   "Paru"
create_sudo_link "$CONFIGS_DIR/pacman/hooks/99-update-pkglist.hook" "/etc/pacman.d/hooks/99-update-pkglist.hook" "Pkglist Hook"
create_sudo_link "$REPO_DIR/scripts/update_pkglist.sh" "/usr/local/bin/archpostinstall-update-pkglist" "Pkglist Sync"
create_sudo_link "$REPO_DIR/scripts/gnome/dpms-toggle.sh" "/usr/local/bin/dpms-toggle" "DPMS Toggle (System)"
create_sudo_link "$CONFIGS_DIR/tlp/99-archpostinstall.conf" "/etc/tlp.d/99-archpostinstall.conf" "TLP"
install_sudoers "$CONFIGS_DIR/sudoers.d/archpostinstall-tlp" "/etc/sudoers.d/archpostinstall-tlp" "TLP Sudoers"

# Shell
create_link "$CONFIGS_DIR/zshrc"            "$HOME/.zshrc"                  "Zshrc"
create_link "$CONFIGS_DIR/zsh"              "$HOME/.config/zsh"             "Zsh Modules"
create_link "$CONFIGS_DIR/p10k.zsh"         "$HOME/.p10k.zsh"               "P10k Config"
create_link "$CONFIGS_DIR/gitconfig"        "$HOME/.gitconfig"              "Gitconfig"

# Terminals
create_link "$CONFIGS_DIR/kitty"           "$HOME/.config/kitty"           "Kitty"
create_link "$CONFIGS_DIR/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml" "Alacritty"
create_link "$CONFIGS_DIR/ghostty"          "$HOME/.config/ghostty"         "Ghostty"
create_link "$CONFIGS_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua" "WezTerm"
create_link "$CONFIGS_DIR/ratty/ratty.toml" "$HOME/.config/ratty/ratty.toml" "Ratty"

# Editors
create_link "$CONFIGS_DIR/nvim"             "$HOME/.config/nvim"            "Neovim"
create_link "$CONFIGS_DIR/zed"              "$HOME/.config/zed"             "Zed"

# Tools
create_link "$CONFIGS_DIR/tmux"             "$HOME/.config/tmux"            "Tmux"
create_link "$CONFIGS_DIR/zellij"           "$HOME/.config/zellij"          "Zellij"
create_link "$CONFIGS_DIR/yazi"             "$HOME/.config/yazi"            "Yazi"
create_link "$CONFIGS_DIR/zathura"          "$HOME/.config/zathura"         "Zathura"
create_link "$CONFIGS_DIR/mpv"              "$HOME/.config/mpv"             "mpv"
create_link "$CONFIGS_DIR/obs-studio/basic/profiles" "$HOME/.config/obs-studio/basic/profiles" "OBS Profiles"
create_link "$CONFIGS_DIR/obs-studio/basic/scenes"   "$HOME/.config/obs-studio/basic/scenes"   "OBS Scenes"
create_link "$CONFIGS_DIR/obs-studio/scripts"        "$HOME/.config/obs-studio/scripts"        "OBS Scripts"
create_link "$CONFIGS_DIR/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal" "XDG Portal"
create_link "$CONFIGS_DIR/xdg-desktop-portal-termfilechooser" "$HOME/.config/xdg-desktop-portal-termfilechooser" "XDG Portal Filechooser"
if [ -f "$CONFIGS_DIR/baidupcs/pcs_config.json" ]; then
    create_link "$CONFIGS_DIR/baidupcs" "$HOME/.config/BaiduPCS-Go" "BaiduPCS-Go"
else
    echo "  [BaiduPCS-Go] Skipped (pcs_config.json missing in configs/baidupcs)"
fi
create_link "$CONFIGS_DIR/fcitx5"           "$HOME/.config/fcitx5"          "Fcitx5"
create_link "$CONFIGS_DIR/rime"             "$HOME/.local/share/fcitx5/rime" "Fcitx5 Rime"
create_link "$CONFIGS_DIR/archpostinstall/dpms.conf" "$HOME/.config/archpostinstall/dpms.conf" "DPMS Config"
create_link "$CONFIGS_DIR/bottom/bottom.toml" "$HOME/.config/bottom/bottom.toml" "bottom"
create_link "$CONFIGS_DIR/btop/btop.conf"   "$HOME/.config/btop/btop.conf"  "btop"

# Applications
create_link "$CONFIGS_DIR/applications/google-chrome.desktop" "$HOME/.local/share/applications/google-chrome.desktop" "Chrome (Custom)"
create_link "$CONFIGS_DIR/applications/QQ.desktop"     "$HOME/.local/share/applications/QQ.desktop"     "QQ"
create_link "$CONFIGS_DIR/applications/yazi.desktop"  "$HOME/.local/share/applications/yazi.desktop"  "Yazi"
create_link "$CONFIGS_DIR/applications/WeChat.desktop" "$HOME/.local/share/applications/WeChat.desktop" "WeChat"
create_link "$CONFIGS_DIR/applications/nowledge-mem.desktop" "$HOME/.local/share/applications/nowledge-mem.desktop" "Nowledge Mem"
create_link "$CONFIGS_DIR/applications/ratty.desktop" "$HOME/.local/share/applications/ratty.desktop" "Ratty"

# Bin (User)
create_link "$REPO_DIR/scripts/gnome/backup_gnome_state.sh" "$HOME/.local/bin/archpostinstall-gnome-sync" "Gnome Sync Bin"
create_link "$REPO_DIR/scripts/archpostinstall.sh" "$HOME/.local/bin/archpostinstall" "Archpostinstall Bin"
create_link "$REPO_DIR/scripts/gnome/dpms-toggle.sh" "$HOME/.local/bin/dpms-toggle" "DPMS Toggle"
create_link "$REPO_DIR/scripts/gnome/dpms-lock-monitor.sh" "$HOME/.local/bin/archpostinstall-dpms-lock-monitor" "DPMS Lock Monitor"
create_link "$REPO_DIR/scripts/power/measure_tlp_power.sh" "$HOME/.local/bin/archpostinstall-measure-power" "Power Measure"
create_link "$REPO_DIR/scripts/launchers/nowledge-mem-desktop.sh" "$HOME/.local/bin/nowledge-mem-desktop" "Nowledge Mem Bin"
create_link "$REPO_DIR/scripts/launchers/yazi-desktop.sh" "$HOME/.local/bin/yazi-desktop" "Yazi Desktop"
create_link "$REPO_DIR/scripts/launchers/yazi-open-nautilus.sh" "$HOME/.local/bin/yazi-open-nautilus" "Yazi Nautilus"
create_link "$REPO_DIR/scripts/zathura/page-to-clipboard.sh" "$HOME/.local/bin/zathura-page-to-clipboard" "Zathura Clipboard"

# Systemd (User)
create_link "$CONFIGS_DIR/systemd/user/archpostinstall-gnome-sync.service" "$HOME/.config/systemd/user/archpostinstall-gnome-sync.service" "Gnome Sync Service"
create_link "$CONFIGS_DIR/systemd/user/archpostinstall-gnome-sync.path"    "$HOME/.config/systemd/user/archpostinstall-gnome-sync.path"    "Gnome Sync Path"
create_link "$CONFIGS_DIR/systemd/user/archpostinstall-dpms-lock-monitor.service" "$HOME/.config/systemd/user/archpostinstall-dpms-lock-monitor.service" "DPMS Lock Monitor Service"

echo ""
echo "✨ Configuration linking complete!"
