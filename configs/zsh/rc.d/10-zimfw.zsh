ZIM_HOME=~/.zim
zstyle ':zim:completion' dumpfile "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"

# Auto-install missing modules and regenerate init.zsh when .zimrc changes.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
    source /usr/share/zimfw/zimfw.zsh init -q
fi

source ${ZIM_HOME}/init.zsh
