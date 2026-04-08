# Compatibility entrypoint for shells that still inherit ZDOTDIR=~/.config/zsh.

if [[ $- != *i* ]]; then
    return
fi

ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/rc.d"

for zsh_config in "$ZSH_CONFIG_DIR"/*.zsh(N); do
    source "$zsh_config"
done

unset ZSH_CONFIG_DIR zsh_config

if [[ -s "$HOME/.bun/_bun" ]] && (( ${+functions[compdef]} )); then
    source "$HOME/.bun/_bun"
fi
