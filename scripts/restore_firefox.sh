#!/bin/bash

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_firefox_backup.tar.gz>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: File '$BACKUP_FILE' not found."
    exit 1
fi

DEST_DIR="$HOME"

echo "Preparing to restore Firefox configuration..."
echo "Source: $BACKUP_FILE"
echo "Destination: $DEST_DIR/.mozilla"

# Check if Firefox is running
if pgrep "firefox" > /dev/null; then
    echo "ERROR: Firefox is running."
    echo "Please close Firefox before restoring configuration."
    exit 1
fi

# Warn about overwriting
if [ -d "$DEST_DIR/.mozilla" ]; then
    echo "WARNING: Existing directory $DEST_DIR/.mozilla will be overwritten/merged."
    echo "It is HIGHLY recommended to back up your current configuration first if you care about it."
    read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 1
    fi
    
    # Optional: clean existng directory for a clean restore?
    # For now, let's just overwrite as requested, but tar usually merges. 
    # To be "seamless override" and avoid mixing old junk files, 
    # it's often safer to move the old one aside.
    
    echo "Moving existing .mozilla to .mozilla.old_$(date +%s)..."
    mv "$DEST_DIR/.mozilla" "$DEST_DIR/.mozilla.old_$(date +%s)"
fi

# Extract
# -C changes to home dir, assuming the archive was created with .mozilla at root
tar -xzf "$BACKUP_FILE" -C "$DEST_DIR"

if [ $? -eq 0 ]; then
    echo "Restore successful!"
else
    echo "Restore failed!"
    exit 1
fi
