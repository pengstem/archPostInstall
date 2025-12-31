#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKGLIST="$REPO_DIR/scripts/pkglist.txt"

if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: pacman is required to update pkglist."
    exit 1
fi

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

{
    echo "# Package list generated on $(date "+%a %b %d %I:%M:%S %p %Z %Y")"
    LC_ALL=C pacman -Qqe | sort
} > "$tmpfile"

install -m 0644 "$tmpfile" "$PKGLIST"

if [[ "$(id -u)" -eq 0 ]]; then
    target_user="${SUDO_USER:-}"
    if [ -z "$target_user" ] && [ -n "${SUDO_UID:-}" ]; then
        target_user="$(getent passwd "$SUDO_UID" | cut -d: -f1 || true)"
    fi
    if [ -z "$target_user" ]; then
        target_user="$(logname 2>/dev/null || true)"
    fi
    if [ -n "$target_user" ]; then
        chown "$target_user":"$target_user" "$PKGLIST" || true
    fi
fi
