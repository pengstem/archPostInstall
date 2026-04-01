ZIM_HOME=~/.zim

# Auto-install missing modules and regenerate init.zsh when .zimrc changes.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
    source /usr/share/zimfw/zimfw.zsh init -q
fi

source ${ZIM_HOME}/init.zsh
