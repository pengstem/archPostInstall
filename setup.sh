#!/bin/bash

# Define the base directory of the repo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to create symlink
create_link() {
    local src="$1"
    local dest="$2"

    echo "Processing $dest..."

    # Check if destination exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # Check if it's already a link to the correct place
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" == "$src" ]; then
            echo "  Already correctly linked."
            return
        fi

        # Backup existing file/dir
        echo "  Backing up existing $dest to $dest.bak"
        mv "$dest" "$dest.bak"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$dest")"

    # Create the link
    ln -s "$src" "$dest"
    echo "  Linked $src -> $dest"
}

# --- Configurations to Link ---

# Tmux
create_link "$REPO_DIR/tmux" "$HOME/.config/tmux"

# Zshrc
create_link "$REPO_DIR/.zshrc" "$HOME/.zshrc"

# Kitty
create_link "$REPO_DIR/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# Neovim
create_link "$REPO_DIR/nvim" "$HOME/.config/nvim"

# Fcitx5
create_link "$REPO_DIR/fcitx5" "$HOME/.config/fcitx5"

# Ghostty
create_link "$REPO_DIR/ghostty" "$HOME/.config/ghostty"

# Zed
create_link "$REPO_DIR/zed" "$HOME/.config/zed"

echo "Setup complete!"
