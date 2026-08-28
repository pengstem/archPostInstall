export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Remind about updates instead of auto-applying them.
zstyle ':omz:update' mode reminder

# Oh My Zsh initializes completion while it loads, so custom completion
# directories must be present in fpath before sourcing oh-my-zsh.sh.
if [[ -d "$HOME/.grok/completions/zsh" ]]; then
    typeset -U fpath
    fpath=("$HOME/.grok/completions/zsh" "${fpath[@]}")
fi

plugins=(
    codex
    fzf
    fzf-tab
    sudo
    extract
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi
