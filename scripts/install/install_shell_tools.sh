#!/bin/bash

set -euo pipefail

# Define directories
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command not found: $1"
    exit 1
  fi
}

require_cmd git
require_cmd curl
if ! command -v zsh >/dev/null 2>&1; then
  echo "Warning: zsh is not installed. Install it before setting it as default shell."
fi

echo "Installing/Updating Shell Tools..."

# 1. Install Oh My Zsh (if not present)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh already installed."
fi

# 2. Install Zsh plugins that are not provided by the package list.

install_plugin() {
  local repo_url=$1
  local plugin_name=$2
  local target_dir="$ZSH_CUSTOM/plugins/$plugin_name"

  if [ ! -d "$target_dir" ]; then
    echo "Installing $plugin_name..."
    git clone --depth=1 "$repo_url" "$target_dir"
  else
    echo "Updating $plugin_name..."
    if [ -d "$target_dir/.git" ]; then
      git -C "$target_dir" pull --ff-only
    else
      echo "Warning: $target_dir exists but is not a git repo. Skipping update."
    fi
  fi
}

# fzf-tab
install_plugin "https://github.com/Aloxaf/fzf-tab" "fzf-tab"

# Powerlevel10k Theme
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  echo "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "Updating Powerlevel10k..."
  if [ -d "$P10K_DIR/.git" ]; then
    git -C "$P10K_DIR" pull --ff-only
  else
    echo "Warning: $P10K_DIR exists but is not a git repo. Skipping update."
  fi
fi

echo "Shell tools setup complete!"
