#!/usr/bin/env zsh

# Compatibility shim for stale ZDOTDIR exports left behind by HyDE.
if [[ ${ZDOTDIR-} == "${XDG_CONFIG_HOME:-$HOME/.config}/zsh" ]]; then
    unset ZDOTDIR
fi
