# Make user-installed CLIs visible before Oh My Zsh plugins initialize.
typeset -U path PATH
path=(
    "$HOME/.local/bin"
    "${path[@]}"
)
export PATH
