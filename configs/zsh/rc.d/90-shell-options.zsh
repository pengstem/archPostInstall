# Keybindings (Emacs mode).
bindkey -e

# Help command support.
unalias run-help 2>/dev/null || true
autoload -Uz run-help

# Sudo toggle: press ESC twice to prepend/remove sudo.
sudo-command-line() {
    [[ -z $BUFFER ]] && LBUFFER="$(fc -ln -1)"
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line
bindkey '\e\e' sudo-command-line
