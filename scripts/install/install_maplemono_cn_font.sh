#!/bin/bash

set -euo pipefail

PACKAGE="ttf-maplemono-nf-cn-unhinted"
CN_REPOSITORY="archlinuxcn"
CN_SERVER="https://repo.archlinuxcn.org/\$arch"
SYSTEM_PACMAN_CONF="/etc/pacman.conf"
PACMAN_SYNC_DIR="/var/lib/pacman/sync"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: required command not found: $1" >&2
        exit 1
    fi
}

usage() {
    cat <<EOF
Usage: $(basename "$0")

Install $PACKAGE from the temporary $CN_REPOSITORY repository.
The repository configuration is not written to $SYSTEM_PACMAN_CONF.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if (($# > 0)); then
    echo "Error: unexpected argument: $1" >&2
    usage >&2
    exit 1
fi

require_cmd pacman
require_cmd pacman-conf
require_cmd sudo

if [[ ! -r "$SYSTEM_PACMAN_CONF" ]]; then
    echo "Error: pacman configuration not found: $SYSTEM_PACMAN_CONF" >&2
    exit 1
fi

if pacman -Qq "$PACKAGE" >/dev/null 2>&1; then
    echo "✅ $PACKAGE is already installed."
    exit 0
fi

sudo -v

TEMP_PACMAN_CONF="$(mktemp)"
TEMP_REPOSITORY_ADDED=false

cleanup() {
    local status=$?

    trap - EXIT

    if [[ "$TEMP_REPOSITORY_ADDED" == true ]]; then
        for db_file in \
            "$PACMAN_SYNC_DIR/$CN_REPOSITORY.db" \
            "$PACMAN_SYNC_DIR/$CN_REPOSITORY.db.sig" \
            "$PACMAN_SYNC_DIR/$CN_REPOSITORY.files" \
            "$PACMAN_SYNC_DIR/$CN_REPOSITORY.files.sig"; do
            sudo rm -f -- "$db_file" || {
                echo "Warning: could not remove temporary repository database: $db_file" >&2
            }
        done
    fi

    rm -f -- "$TEMP_PACMAN_CONF"
    exit "$status"
}

trap cleanup EXIT

cp -- "$SYSTEM_PACMAN_CONF" "$TEMP_PACMAN_CONF"

if pacman-conf --repo-list | grep -Fxq "$CN_REPOSITORY"; then
    echo "Using the existing $CN_REPOSITORY repository configuration."
else
    printf '\n[%s]\nServer = %s\n' "$CN_REPOSITORY" "$CN_SERVER" >>"$TEMP_PACMAN_CONF"
    TEMP_REPOSITORY_ADDED=true
    echo "Using a temporary $CN_REPOSITORY repository configuration."
fi

echo "Importing the $CN_REPOSITORY signing keyring..."
sudo pacman --config "$TEMP_PACMAN_CONF" -Sy --needed --noconfirm \
    "$CN_REPOSITORY/archlinuxcn-keyring"

echo "Installing $PACKAGE from $CN_REPOSITORY..."
sudo pacman --config "$TEMP_PACMAN_CONF" -S --needed --noconfirm \
    "$CN_REPOSITORY/$PACKAGE"

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || true
fi

echo "✅ $PACKAGE installed. The temporary $CN_REPOSITORY source has been removed."
