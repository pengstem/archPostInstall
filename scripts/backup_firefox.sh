#!/bin/bash

set -euo pipefail

# Default backup name with timestamp
BACKUP_NAME="firefox_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
OUTPUT_DIR="${1:-$(pwd)}"
mkdir -p "$OUTPUT_DIR"
if [ ! -w "$OUTPUT_DIR" ]; then
    echo "Error: Output directory is not writable: $OUTPUT_DIR"
    exit 1
fi

OUTPUT_FILE="${OUTPUT_DIR}/${BACKUP_NAME}"

echo "Preparing to backup Firefox configuration..."
echo "Source: $HOME/.mozilla"
echo "Destination: $OUTPUT_FILE"

# Check if Firefox is running
if command -v pgrep >/dev/null 2>&1; then
    if pgrep -x "firefox" > /dev/null; then
        echo "WARNING: Firefox seems to be running."
        echo "It is recommended to close Firefox before backing up to ensure data consistency."
        read -r -p "Continue anyway? (y/N) " -n 1
        echo
        if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
            echo "Backup cancelled."
            exit 1
        fi
    fi
fi

# Create the tarball
# -C changes to home dir so the archive contains .mozilla at the root
tar -czf "$OUTPUT_FILE" -C "$HOME" .mozilla

echo "Backup successful: $OUTPUT_FILE"
