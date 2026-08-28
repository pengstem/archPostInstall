# Startup greeting: a random fortune delivered by a random cowfile.
# Printed at source time on purpose: Powerlevel10k's instant prompt captures
# console output produced during initialization into a buffer and replays it
# above the first prompt, which is exactly where this greeting belongs. The
# matching POWERLEVEL9K_INSTANT_PROMPT=quiet in 00-instant-prompt.zsh keeps
# p10k from flagging this deliberate output with its init-output warning.
() {
    emulate -L zsh
    (( $+commands[fortune] && $+commands[cowsay] )) || return
    local -a cowfiles
    cowfiles=(/usr/share/cowsay/cows/*.cow(N))
    (( $#cowfiles )) || return
    fortune -s | cowsay -f ${cowfiles[RANDOM % $#cowfiles + 1]:t:r}
}
