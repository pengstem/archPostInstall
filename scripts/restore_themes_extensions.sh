#!/bin/bash

set -euo pipefail

# Usage: ./restore_themes_extensions.sh <themes.tar.gz> <icons.tar.gz> <extensions.tar.gz>
# You can pass arguments in any order, the script attempts to detect content type or just extracts to standard locations.
# Actually, strict ordering or flags is better. Let's rely on simple extraction logic.

if [ $# -eq 0 ]; then
    echo "Usage: $0 [file1.tar.gz] [file2.tar.gz] ..."
    echo "Pass any combination of themes, icons, or extension backups."
    exit 1
fi

for FILE in "$@"; do
    if [ ! -f "$FILE" ]; then
        echo "File not found: $FILE"
        continue
    fi
    
    echo "Processing $FILE..."
    
    # Try to detect content by listing first few files
    CONTENT=$(tar -tf "$FILE" | head -n 1)
    TOP_LEVEL="${CONTENT#./}"
    TOP_LEVEL="${TOP_LEVEL%%/*}"

    if [[ "$TOP_LEVEL" == ".themes" ]]; then
        echo "  Detected Themes backup."
        echo "  Extracting to $HOME..."
        tar -xzf "$FILE" -C "$HOME"
    
    elif [[ "$TOP_LEVEL" == "icons" ]]; then
        echo "  Detected Icons backup."
        mkdir -p "$HOME/.local/share"
        echo "  Extracting to $HOME/.local/share..."
        tar -xzf "$FILE" -C "$HOME/.local/share"
        
    elif [[ "$TOP_LEVEL" == "extensions" ]]; then
        echo "  Detected Gnome Extensions backup."
        mkdir -p "$HOME/.local/share/gnome-shell"
        echo "  Extracting to $HOME/.local/share/gnome-shell..."
        tar -xzf "$FILE" -C "$HOME/.local/share/gnome-shell"
        
    else
        echo "  Unknown backup format (top level directory: $TOP_LEVEL). Skipping."
    fi
done

echo "Restore process finished."
