# Bun completion.
if [[ -s "$BUN_INSTALL/_bun" ]] && (( ${+functions[compdef]} )); then
    source "$BUN_INSTALL/_bun"
fi

# Zoxide: replace cd with smart jump.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# Powerlevel10k user config.
if [[ -f "$HOME/.p10k.zsh" ]]; then
    source "$HOME/.p10k.zsh"
fi
