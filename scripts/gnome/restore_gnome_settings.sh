#!/bin/bash

set -euo pipefail

# Load the tracked GNOME Shell extension settings into dconf. `dconf load`
# merges: keys missing from the file (machine-specific or volatile ones that
# backup_gnome_state.sh filters out) keep their current values.

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

EXT_SETTINGS_FILE="$REPO_DIR/configs/dconf/shell-extensions.ini"
EXT_SETTINGS_DIR="/org/gnome/shell/extensions/"

if [ "$EUID" -eq 0 ]; then
    echo "Error: Run as your user, not root (dconf settings are per user)."
    exit 1
fi

if ! command -v dconf >/dev/null 2>&1; then
    echo "Error: Required command not found: dconf"
    exit 1
fi

if [ ! -f "$EXT_SETTINGS_FILE" ]; then
    echo "Error: Settings file not found: $EXT_SETTINGS_FILE"
    exit 1
fi

dconf load "$EXT_SETTINGS_DIR" <"$EXT_SETTINGS_FILE"
echo "Loaded GNOME Shell extension settings from $EXT_SETTINGS_FILE"
