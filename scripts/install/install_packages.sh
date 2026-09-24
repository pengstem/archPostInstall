#!/bin/bash

# Install scripts/pkglist/: native.txt and hw-<host>.txt through pacman in one
# transaction, then aur.txt through an AUR helper, so a failing AUR build
# cannot block the repository packages.

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PKGLIST_DIR="$REPO_DIR/scripts/pkglist"
HOST="${ARCHPOSTINSTALL_HOST:-$(uname -n)}"
HW_LIST="$PKGLIST_DIR/hw-$HOST.txt"

if [[ "${EUID}" -eq 0 ]]; then
    echo "Please run this script as a regular user with sudo privileges."
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

# Package names from list files, without comments or blank lines.
read_list() {
    sed -e 's/#.*//' -e 's/[[:space:]]//g' -- "$@" | sed '/^$/d'
}

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

# 1. Repository packages
REPO_LISTS=("$PKGLIST_DIR/native.txt")
if [ -f "$HW_LIST" ]; then
    REPO_LISTS+=("$HW_LIST")
    echo "   Hardware list: ${HW_LIST#"$REPO_DIR"/}"
else
    echo "   ⚠️ No hardware list for host '$HOST' (set ARCHPOSTINSTALL_HOST to reuse one)."
fi

mapfile -t REPO_PACKAGES < <(read_list "${REPO_LISTS[@]}")
if ((${#REPO_PACKAGES[@]})); then
    echo "   Installing ${#REPO_PACKAGES[@]} repository packages with pacman..."
    sudo pacman -S --needed --noconfirm "${REPO_PACKAGES[@]}"
fi

# 2. AUR packages
mapfile -t AUR_PACKAGES < <(read_list "$PKGLIST_DIR/aur.txt")
if ((${#AUR_PACKAGES[@]})); then
    if command -v paru >/dev/null; then
        AUR_CMD=(paru -S --needed --noconfirm)
        echo "   Using: paru (Already installed)"
    elif command -v yay >/dev/null; then
        AUR_CMD=(yay -S --needed --noconfirm)
        echo "   Using: yay"
    else
        echo "   ⚠️ No AUR helper found. Installing paru..."
        install_paru
        AUR_CMD=(paru -S --needed --noconfirm)
    fi

    echo "   Installing ${#AUR_PACKAGES[@]} AUR packages..."
    "${AUR_CMD[@]}" "${AUR_PACKAGES[@]}"
fi

echo "   ✅ Package installation process finished."
