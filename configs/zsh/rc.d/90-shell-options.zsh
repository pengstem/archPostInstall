# Keybindings (Emacs mode).
bindkey -e

# Edit the current command line with kitty-scrollback.nvim.
export KITTY_SCROLLBACK_NVIM_EDIT_ARGS='--nvim-args -n'
autoload -Uz edit-command-line
zle -N edit-command-line
kitty_scrollback_edit_command_line() {
    local VISUAL='/home/nastem/.local/share/nvim/lazy/kitty-scrollback.nvim/scripts/edit_command_line.sh'
    zle edit-command-line
    zle kill-whole-line
}
zle -N kitty_scrollback_edit_command_line
bindkey '^x^e' kitty_scrollback_edit_command_line

# Help command support.
unalias run-help 2>/dev/null || true
autoload -Uz run-help

# Completion system.
# -C skips insecure directory checks for faster startup.
autoload -Uz compinit
compinit -C

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
