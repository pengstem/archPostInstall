#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKGLIST="$REPO_DIR/scripts/pkglist.txt"

if [[ "${EUID}" -eq 0 ]]; then
    echo "Error: run as the repository owner; the pacman hook drops privileges via runuser." >&2
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: pacman is required to update pkglist."
    exit 1
fi

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

{
    echo "# Package list generated on $(date "+%a %b %d %I:%M:%S %p %Z %Y")"
    LC_ALL=C pacman -Qqe | grep -vE '^paru(-debug)?$' | sort
} > "$tmpfile"

install -m 0644 "$tmpfile" "$PKGLIST"

