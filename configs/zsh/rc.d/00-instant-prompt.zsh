# Powerlevel10k instant prompt.
# Keep this at the top of interactive shell initialization for best startup UX.
# The greeting in 85-fortune-cowsay.zsh intentionally writes to the console
# during initialization; p10k buffers and replays that output above the first
# prompt. POWERLEVEL9K_INSTANT_PROMPT=quiet in ~/.p10k.zsh (configs/p10k.zsh)
# suppresses the warning p10k would otherwise print for that replayed output.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
