# Startup greeting: a random fortune delivered by a random cowfile.
# Runs in an anonymous function so the cowfile array doesn't leak into
# the interactive session.
() {
    emulate -L zsh
    (( $+commands[fortune] && $+commands[cowsay] )) || return
    local -a cowfiles
    cowfiles=(/usr/share/cowsay/cows/*.cow(N))
    (( $#cowfiles )) || return
    fortune -s | cowsay -f ${cowfiles[RANDOM % $#cowfiles + 1]:t:r}
}
