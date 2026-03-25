#!/bin/bash
set -euo pipefail

main() {
    local target="${1-}"

    if ! command -v nautilus >/dev/null 2>&1; then
        echo "yazi-open-nautilus: nautilus is not installed" >&2
        exit 1
    fi

    if [[ -z "$target" ]]; then
        exec nautilus --new-window .
    elif [[ -d "$target" ]]; then
        exec nautilus --new-window "$target"
    else
        exec nautilus --new-window --select "$target"
    fi
}

main "$@"
