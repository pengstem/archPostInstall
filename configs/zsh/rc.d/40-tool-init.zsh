# NVM (Node Version Manager).
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi
if [[ -s "$NVM_DIR/bash_completion" ]]; then
    source "$NVM_DIR/bash_completion"
fi

# Bun completion.
if [[ -s "$BUN_INSTALL/_bun" ]]; then
    source "$BUN_INSTALL/_bun"
fi

# opam shell integration.
OPAM_INIT_ZSH="${OPAMROOT:-$HOME/.opam}/opam-init/init.zsh"
if [[ -r "$OPAM_INIT_ZSH" ]]; then
    source "$OPAM_INIT_ZSH" >/dev/null 2>&1
fi
unset OPAM_INIT_ZSH

# Zoxide: replace cd with smart jump.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# TheFuck alias helper. Generating the real function starts Python, so defer it
# until the first time the command is used.
if command -v thefuck >/dev/null 2>&1; then
    _archpostinstall_load_thefuck() {
        local thefuck_init

        thefuck_init="$(command thefuck --alias)" || return
        eval "$thefuck_init" || return
        unfunction _archpostinstall_load_thefuck
    }

    fuck() {
        _archpostinstall_load_thefuck || return
        fuck "$@"
    }
fi

# Powerlevel10k user config.
if [[ -f "$HOME/.p10k.zsh" ]]; then
    source "$HOME/.p10k.zsh"
fi
