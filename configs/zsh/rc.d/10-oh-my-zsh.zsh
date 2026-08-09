export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Remind about updates instead of auto-applying them.
zstyle ':omz:update' mode reminder

plugins=(
    archlinux
    codex
    gitignore
    git
    fzf
    fzf-tab
    zsh-autosuggestions
    tldr
    web-search
    sudo
    zsh-syntax-highlighting
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi
