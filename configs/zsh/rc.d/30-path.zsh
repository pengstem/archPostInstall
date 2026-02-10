# Use tied PATH/path arrays with uniqueness to avoid duplicate path entries.
typeset -U path PATH
path=(
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
    "$BUN_INSTALL/bin"
    "$PNPM_HOME"
    "${path[@]}"
)
export PATH
