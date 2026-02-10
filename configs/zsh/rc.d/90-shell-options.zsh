# Keybindings (Emacs mode).
bindkey -e

# Help command support.
unalias run-help 2>/dev/null || true
autoload -Uz run-help

# Completion system.
# -C skips insecure directory checks for faster startup.
autoload -Uz compinit
compinit -C
