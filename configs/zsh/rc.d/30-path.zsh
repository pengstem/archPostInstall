# Use tied PATH/path arrays with uniqueness to avoid duplicate path entries.
typeset -U path PATH
path=(
    "$HOME/.grok/bin"
    "$HOME/.local/bin"
    "$HOME/x-tools/loongarch64-unknown-linux-musl/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
    "$BUN_INSTALL/bin"
    "$PNPM_HOME"
    "${path[@]}"
)
export PATH
