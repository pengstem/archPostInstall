#!/bin/bash

set -euo pipefail

OUTPUT_DIR="${1:-$(pwd)}"
mkdir -p "$OUTPUT_DIR"
if [ ! -w "$OUTPUT_DIR" ]; then
    echo "Error: Output directory is not writable: $OUTPUT_DIR"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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

echo "Backup process finished."
