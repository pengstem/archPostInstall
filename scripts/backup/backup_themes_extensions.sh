#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

OUTPUT_DIR="${1:-$REPO_DIR/backups/gnome}"
mkdir -p "$OUTPUT_DIR"
if [ ! -w "$OUTPUT_DIR" ]; then
    echo "Error: Output directory is not writable: $OUTPUT_DIR"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
THEMES_PATTERN="themes_backup_*.tar.gz"
ICONS_PATTERN="icons_backup_*.tar.gz"
EXTENSIONS_PATTERN="gnome_extensions_backup_*.tar.gz"

get_dir_hash() {
    local path="$1"
    if [ ! -d "$path" ]; then
        echo ""
        return 0
    fi

    find "$path" -type f -print0 2>/dev/null \
        | sort -z \
        | xargs -0 sha256sum 2>/dev/null \
        | sha256sum \
        | awk '{print $1}'
}

hash_changed() {
    local new_hash="$1"
    local hash_file="$2"
    local old_hash=""

    if [ -f "$hash_file" ]; then
        old_hash="$(cat "$hash_file" 2>/dev/null || true)"
    fi

    if [ -n "$old_hash" ] && [ "$new_hash" = "$old_hash" ]; then
        return 1
    fi

    return 0
}

backup_exists() {
    local output_dir="$1"
    local pattern="$2"
    local -a matches=()

    shopt -s nullglob
    matches=("$output_dir"/$pattern)
    shopt -u nullglob

    ((${#matches[@]} > 0))
}

prune_backups_keep_newest() {
    local output_dir="$1"
    local pattern="$2"
    local -a files=()
    local file

    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$output_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)

    if ((${#files[@]} <= 1)); then
        return 0
    fi

    local newest
    newest="$(ls -t "${files[@]}" | head -n 1)"
    for file in "${files[@]}"; do
        if [ "$file" != "$newest" ]; then
            rm -f "$file"
        fi
    done
}

# 1. Backup Themes (~/.themes)
THEMES_HASH_FILE="$OUTPUT_DIR/.themes_last_hash"
if [ -d "$HOME/.themes" ]; then
    THEMES_HASH="$(get_dir_hash "$HOME/.themes")"
    if hash_changed "$THEMES_HASH" "$THEMES_HASH_FILE" || ! backup_exists "$OUTPUT_DIR" "$THEMES_PATTERN"; then
        THEME_BACKUP="$OUTPUT_DIR/themes_backup_$TIMESTAMP.tar.gz"
        echo "Backing up ~/.themes to $THEME_BACKUP ..."
        tar -czf "$THEME_BACKUP" -C "$HOME" .themes
        echo "$THEMES_HASH" > "$THEMES_HASH_FILE"
    else
        echo "Themes unchanged, skipping."
    fi
else
    echo "No ~/.themes found, skipping."
fi

# 2. Backup Icons (~/.local/share/icons)
# Note: This might contain system icons if not careful, but usually ~/.local/share/icons is user specific.
ICONS_HASH_FILE="$OUTPUT_DIR/.icons_last_hash"
if [ -d "$HOME/.local/share/icons" ]; then
    ICONS_HASH="$(get_dir_hash "$HOME/.local/share/icons")"
    if hash_changed "$ICONS_HASH" "$ICONS_HASH_FILE" || ! backup_exists "$OUTPUT_DIR" "$ICONS_PATTERN"; then
        ICON_BACKUP="$OUTPUT_DIR/icons_backup_$TIMESTAMP.tar.gz"
        echo "Backing up ~/.local/share/icons to $ICON_BACKUP ..."
        # We cd to ~/.local/share so the archive starts with 'icons'
        tar -czf "$ICON_BACKUP" -C "$HOME/.local/share" icons
        echo "$ICONS_HASH" > "$ICONS_HASH_FILE"
    else
        echo "Icons unchanged, skipping."
    fi
else
    echo "No ~/.local/share/icons found, skipping."
fi

# 3. Backup Gnome Extensions (~/.local/share/gnome-shell/extensions)
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
if [ -d "$EXT_DIR" ]; then
    EXT_BACKUP="$OUTPUT_DIR/gnome_extensions_backup_$TIMESTAMP.tar.gz"
    echo "Backing up Gnome Extensions to $EXT_BACKUP ..."
    # We cd to ~/.local/share/gnome-shell so archive starts with 'extensions'
    tar -czf "$EXT_BACKUP" -C "$HOME/.local/share/gnome-shell" extensions
else
    echo "No extensions found in $EXT_DIR, skipping."
fi

prune_backups_keep_newest "$OUTPUT_DIR" "$THEMES_PATTERN"
prune_backups_keep_newest "$OUTPUT_DIR" "$ICONS_PATTERN"
prune_backups_keep_newest "$OUTPUT_DIR" "$EXTENSIONS_PATTERN"

echo "Backup process finished."
