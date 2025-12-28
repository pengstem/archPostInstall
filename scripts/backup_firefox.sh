#!/bin/bash

# Default backup name with timestamp
BACKUP_NAME="firefox_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
OUTPUT_DIR="$(pwd)"

# Allow user to override output directory
if [ -n "$1" ]; then
    OUTPUT_DIR="$1"
fi

OUTPUT_FILE="${OUTPUT_DIR}/${BACKUP_NAME}"

echo "Preparing to backup Firefox configuration..."
echo "Source: $HOME/.mozilla"
echo "Destination: $OUTPUT_FILE"

# Check if Firefox is running
if pgrep "firefox" > /dev/null; then
    echo "WARNING: Firefox seems to be running."
    echo "It is recommended to close Firefox before backing up to ensure data consistency."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Backup cancelled."
        exit 1
    fi
fi

# Create the tarball
# -C changes to home dir so the archive contains .mozilla at the root
tar -czf "$OUTPUT_FILE" -C "$HOME" .mozilla

if [ $? -eq 0 ]; then
    echo "Backup successful: $OUTPUT_FILE"
else
    echo "Backup failed!"
    exit 1
fi
