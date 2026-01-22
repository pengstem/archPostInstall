#!/bin/bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 1

tmp=$(mktemp -u)
trap 'rm -f "$tmp.png"' EXIT

if pdftoppm -png -f "$2" -l "$2" -singlefile "$1" "$tmp" && wl-copy -t image/png < "$tmp.png"; then
    notify-send -t 1500 "Zathura" "Page $2 copied"
else
    notify-send -u critical "Zathura" "Copy failed"
fi
