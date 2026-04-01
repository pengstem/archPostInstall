#!/bin/bash

set -euo pipefail

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command not found: $1"
        exit 1
    fi
}

require_cmd zsh

ZIMFW="/usr/share/zimfw/zimfw.zsh"

echo "Installing/Updating Shell Tools..."

# Install zimfw modules (reads ~/.zimrc, downloads to ~/.zim/).
if [[ -r "$ZIMFW" ]]; then
    echo "Installing zimfw modules..."
    zsh -c "ZIM_HOME=~/.zim source '${ZIMFW}' init && zimfw install"
else
    echo "Warning: zimfw not found at $ZIMFW. Install it with: yay -S zimfw"
fi

echo "Shell tools setup complete!"
echo "Note: You might need to log out and back in or run 'zsh' to see changes."
