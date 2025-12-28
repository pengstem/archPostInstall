#!/bin/bash

# Define directories
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "Installing/Updating Shell Tools..."

# 1. Install Oh My Zsh (if not present)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh already installed."
fi

# 2. Install Zsh Plugins (git clone to custom folder)

install_plugin() {
  local repo_url=$1
  local plugin_name=$2
  local target_dir="$ZSH_CUSTOM/plugins/$plugin_name"

  if [ ! -d "$target_dir" ]; then
    echo "Installing $plugin_name..."
    git clone "$repo_url" "$target_dir"
  else
    echo "Updating $plugin_name..."
    git -C "$target_dir" pull
  fi
}

# zsh-autosuggestions
install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"

# zsh-syntax-highlighting
install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting"

# fzf-tab
install_plugin "https://github.com/Aloxaf/fzf-tab" "fzf-tab"

# Powerlevel10k Theme
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  echo "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "Updating Powerlevel10k..."
  git -C "$P10K_DIR" pull
fi

echo "Shell tools setup complete!"
echo "Note: You might need to log out and back in or run 'zsh' to see changes."
