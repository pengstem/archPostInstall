# Modern replacements for standard commands (using eza).
alias ls='eza --icons'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias lt='eza --tree --level=2 --icons'

# System utilities.
alias st='systemctl-tui'

# Mail.
alias mutt='mbsync -a && TERM=xterm-direct neomutt'

# Global aliases for highlighted help output.
alias -g -- --h1='-h 2>&1 | bat --language=help --style=plain'
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
