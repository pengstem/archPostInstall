#!/bin/bash

# Regenerate scripts/pkglist/{native,aur}.txt from the explicitly installed
# packages, leaving out ignore.txt and anything claimed by a hw-*.txt file.

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PKGLIST_DIR="$SCRIPT_DIR/pkglist"

if [[ "${EUID}" -eq 0 ]]; then
    echo "Error: run as the repository owner; the pacman hook drops privileges via runuser." >&2
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: pacman is required to update pkglist."
    exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Package names from list files, without comments or blank lines.
read_lists() {
    cat -- "$@" 2>/dev/null | sed -e 's/#.*//' -e 's/[[:space:]]//g' | sed '/^$/d' || true
}

read_lists "$PKGLIST_DIR/ignore.txt" "$PKGLIST_DIR"/hw-*.txt | LC_ALL=C sort -u >"$tmp_dir/exclude"

write_list() {
    local name="$1"
    local pacman_flag="$2"

    LC_ALL=C pacman -Qqe"$pacman_flag" | LC_ALL=C sort |
        LC_ALL=C comm -23 - "$tmp_dir/exclude" >"$tmp_dir/$name"
    # Only touch the tracked file when its content changes.
    if ! cmp -s -- "$tmp_dir/$name" "$PKGLIST_DIR/$name"; then
        install -m 0644 -- "$tmp_dir/$name" "$PKGLIST_DIR/$name"
    fi
}

write_list native.txt n
write_list aur.txt m
