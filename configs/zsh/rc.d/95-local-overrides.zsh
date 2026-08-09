# Machine-specific overrides and secrets should go here and stay out of git:
#   ~/.zshrc.local
if [[ -r "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
