#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

EXT_FILE="$REPO_DIR/docs/gnome-extensions.md"
APPEAR_FILE="$REPO_DIR/docs/gnome-appearrance.md"
BACKUP_DIR="${GNOME_BACKUP_DIR:-$REPO_DIR/backups/gnome}"
THROTTLE_SECONDS="${GNOME_SYNC_THROTTLE_SECONDS:-1800}"
STAMP_FILE="$BACKUP_DIR/.last_backup"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command not found: $1"
        exit 1
    fi
}

require_cmd gsettings

SCHEMAS="$(gsettings list-schemas)"

has_schema() {
    echo "$SCHEMAS" | grep -qx "$1"
}

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$EXT_FILE")"

EXT_LIST=""
if has_schema "org.gnome.shell"; then
    EXT_RAW="$(gsettings get org.gnome.shell enabled-extensions || true)"
    EXT_LIST="$(echo "$EXT_RAW" | sed -e 's/^\[//; s/\]$//' -e "s/'//g" -e 's/, /\n/g' | sed '/^$/d')"
fi
printf "%s\n" "$EXT_LIST" > "$EXT_FILE"

get_setting() {
    local schema="$1"
    local key="$2"
    if ! has_schema "$schema"; then
        return 0
    fi
    gsettings get "$schema" "$key" 2>/dev/null | tr -d "'"
}

CURSOR_THEME="$(get_setting org.gnome.desktop.interface cursor-theme)"
ICON_THEME="$(get_setting org.gnome.desktop.interface icon-theme)"
GTK_THEME="$(get_setting org.gnome.desktop.interface gtk-theme)"
SHELL_THEME=""
if has_schema "org.gnome.shell.extensions.user-theme"; then
    SHELL_THEME="$(get_setting org.gnome.shell.extensions.user-theme name)"
fi

{
    [ -n "$CURSOR_THEME" ] && echo "Cursor $CURSOR_THEME"
    [ -n "$ICON_THEME" ] && echo "Icons $ICON_THEME"
    [ -n "$SHELL_THEME" ] && echo "Shell $SHELL_THEME"
    [ -n "$GTK_THEME" ] && echo "legacy application $GTK_THEME"
} > "$APPEAR_FILE"

now="$(date +%s)"
last_backup=0
if [ -f "$STAMP_FILE" ]; then
    last_backup="$(cat "$STAMP_FILE" 2>/dev/null || echo 0)"
fi

if (( now - last_backup >= THROTTLE_SECONDS )); then
    "$REPO_DIR/scripts/backup/backup_themes_extensions.sh" "$BACKUP_DIR"
    echo "$now" > "$STAMP_FILE"
else
    echo "Skipping archive backup (throttled)."
fi
