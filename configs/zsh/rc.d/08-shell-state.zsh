# Define shell state before Oh My Zsh initializes completion and history.
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

zsh_cache_dir="${XDG_CACHE_HOME}/zsh"
zsh_state_dir="${XDG_STATE_HOME}/zsh"

if [[ ! -d "$zsh_cache_dir" || ! -d "$zsh_state_dir" ]]; then
    mkdir -p "$zsh_cache_dir" "$zsh_state_dir"
fi

export HISTFILE="${zsh_state_dir}/history"
ZSH_COMPDUMP="${zsh_cache_dir}/zcompdump-${HOST%%.*}-${ZSH_VERSION}"

unset zsh_cache_dir zsh_state_dir
