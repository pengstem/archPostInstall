export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Remind about updates instead of auto-applying them.
zstyle ':omz:update' mode reminder

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
    fzf-tab
    tldr
    web-search
    sudo
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi
