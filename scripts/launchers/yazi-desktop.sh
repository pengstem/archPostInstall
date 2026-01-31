#!/bin/bash
set -euo pipefail

PERCENT="${YAZI_DESKTOP_PERCENT:-90}"

get_resolution() {
    local resolution

    resolution="$(xrandr --current | awk '/ primary/{print $4; exit}')"
    if [ -z "$resolution" ]; then
        resolution="$(xrandr --current | awk '/\*/{print $1; exit}')"
    fi
    if [ -z "$resolution" ]; then
        echo "yazi-desktop: unable to determine screen resolution" >&2
        return 1
    fi

    printf "%s" "${resolution%%+*}"
}

main() {
    local resolution width height target_width target_height

    resolution="$(get_resolution)"
    width="${resolution%x*}"
    height="${resolution#*x}"
    target_width=$((width * PERCENT / 100))
    target_height=$((height * PERCENT / 100))

    exec kitty \
        -o remember_window_size=no \
        -o initial_window_width="${target_width}" \
        -o initial_window_height="${target_height}" \
        --class yazi \
        --title yazi \
        yazi "$@"
}

main "$@"
