# Startup greeting: a random fortune delivered by a random cowfile.
# Printed by a one-shot precmd hook instead of at source time so that no
# console I/O happens during zsh initialization, which keeps Powerlevel10k's
# instant prompt warning-free. The hook removes itself before printing so the
# greeting appears exactly once, above the first real prompt.
_fortune_cowsay_greet() {
    emulate -L zsh
    precmd_functions=(${precmd_functions:#_fortune_cowsay_greet})
    (( $+commands[fortune] && $+commands[cowsay] )) || return
    local -a cowfiles
    cowfiles=(/usr/share/cowsay/cows/*.cow(N))
    (( $#cowfiles )) || return
    fortune -s | cowsay -f ${cowfiles[RANDOM % $#cowfiles + 1]:t:r}
}
precmd_functions+=(_fortune_cowsay_greet)
