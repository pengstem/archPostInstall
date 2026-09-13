# Modern replacements for standard commands (using eza).
alias ls='eza --icons=auto --hyperlink=auto'
alias ll='eza -l --icons=auto --git --hyperlink=auto'
alias la='eza -la --icons=auto --git --hyperlink=auto'
alias lt='eza --tree --level=2 --icons=auto --hyperlink=auto'

# System utilities.
alias st='systemctl-tui'


# Global aliases for highlighted help output.
alias -g -- --h1='-h 2>&1 | bat --language=help --style=plain'
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'

# wayland copy
alias copy="wl-copy"
alias paste="wl-paste"
