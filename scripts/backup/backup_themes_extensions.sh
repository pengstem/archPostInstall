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
RETENTION_DAYS="${GNOME_BACKUP_RETENTION_DAYS:-30}"

prune_old_backups() {
    local retention_days="$1"
    local output_dir="$2"
    local -a patterns=(
        "themes_backup_*.tar.gz"
        "icons_backup_*.tar.gz"
        "gnome_extensions_backup_*.tar.gz"
    )

    if (( retention_days <= 0 )); then
        echo "Skipping old GNOME backup cleanup (retention disabled)."
        return 0
    fi

    local -a find_expr=()
    local pattern
    for pattern in "${patterns[@]}"; do
        find_expr+=(-name "$pattern" -o)
    done
    unset 'find_expr[${#find_expr[@]}-1]'

    local -a old_files=()
    while IFS= read -r file; do
        old_files+=("$file")
    done < <(find "$output_dir" -maxdepth 1 -type f \( "${find_expr[@]}" \) -mtime "+$retention_days" 2>/dev/null)

    if ((${#old_files[@]} == 0)); then
        echo "No old GNOME backups to prune."
        return 0
    fi

    echo "Pruning ${#old_files[@]} old GNOME backup(s) older than ${retention_days} day(s)..."
    rm -f "${old_files[@]}"
}

# 1. Backup Themes (~/.themes)
if [ -d "$HOME/.themes" ]; then
    THEME_BACKUP="$OUTPUT_DIR/themes_backup_$TIMESTAMP.tar.gz"
    echo "Backing up ~/.themes to $THEME_BACKUP ..."
    tar -czf "$THEME_BACKUP" -C "$HOME" .themes
else
    echo "No ~/.themes found, skipping."
fi

# 2. Backup Icons (~/.local/share/icons)
# Note: This might contain system icons if not careful, but usually ~/.local/share/icons is user specific.
if [ -d "$HOME/.local/share/icons" ]; then
    ICON_BACKUP="$OUTPUT_DIR/icons_backup_$TIMESTAMP.tar.gz"
    echo "Backing up ~/.local/share/icons to $ICON_BACKUP ..."
    # We cd to ~/.local/share so the archive starts with 'icons'
    tar -czf "$ICON_BACKUP" -C "$HOME/.local/share" icons
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

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
    prune_old_backups "$RETENTION_DAYS" "$OUTPUT_DIR"
else
    echo "Warning: GNOME_BACKUP_RETENTION_DAYS must be a non-negative integer. Skipping cleanup."
fi

echo "Backup process finished."
