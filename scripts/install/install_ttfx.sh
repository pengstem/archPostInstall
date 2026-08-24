#!/bin/bash

set -euo pipefail

readonly MIN_TTFX_VERSION="0.3.2"
readonly PINNED_TTFX_REVISION="7203e354498462064b7c0a89375051f65cf2ce99"
readonly TTFX_REPOSITORY="https://github.com/omacom-io/ttfx.git"

INSTALL_ROOT="${TTFX_INSTALL_ROOT:-$HOME/.local}"
TTFX_BIN="$INSTALL_ROOT/bin/ttfx"

usage() {
    cat <<'EOF'
Usage: install_ttfx.sh [install|upgrade]

Commands:
  install  Install the pinned minimum version, without downgrading (default)
  upgrade  Build and install the newest stable tag from the official repository
EOF
}

installed_version() {
    [ -x "$TTFX_BIN" ] || return 1
    "$TTFX_BIN" --version 2>/dev/null | awk '$1 == "ttfx" {print $2; exit}'
}

version_at_least() {
    local actual="$1" minimum="$2"

    [[ "$actual" =~ ^[0-9]+([.][0-9]+){2}$ ]] || return 1
    [ "$(printf '%s\n%s\n' "$minimum" "$actual" | sort -V | head -n 1)" = "$minimum" ]
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: required command not found: $1" >&2
        exit 1
    fi
}

verify_install() {
    local expected="$1" actual

    actual="$(installed_version || true)"
    if [ "$actual" != "$expected" ]; then
        echo "Error: installed ttfx reported '$actual', expected '$expected'." >&2
        exit 1
    fi
    echo "Installed ttfx $actual at $TTFX_BIN."
}

install_pinned() {
    local current

    current="$(installed_version || true)"
    if [ -n "$current" ] && version_at_least "$current" "$MIN_TTFX_VERSION"; then
        echo "ttfx $current already satisfies the minimum $MIN_TTFX_VERSION at $TTFX_BIN."
        return 0
    fi

    require_cmd cargo
    echo "Building ttfx $MIN_TTFX_VERSION from pinned revision $PINNED_TTFX_REVISION..."
    cargo install \
        --git "$TTFX_REPOSITORY" \
        --rev "$PINNED_TTFX_REVISION" \
        --locked \
        --force \
        --root "$INSTALL_ROOT" \
        ttfx
    verify_install "$MIN_TTFX_VERSION"
}

upgrade_latest() {
    local current latest_tag latest_version

    require_cmd cargo
    require_cmd git
    latest_tag="$(
        git ls-remote --refs --tags "$TTFX_REPOSITORY" \
            | awk -F/ '$3 ~ /^v[0-9]+[.][0-9]+[.][0-9]+$/ {print $3}' \
            | sort -V \
            | tail -n 1
    )"
    if [ -z "$latest_tag" ]; then
        echo "Error: no stable ttfx release tag was found." >&2
        exit 1
    fi
    latest_version="${latest_tag#v}"
    current="$(installed_version || true)"
    if [ "$current" = "$latest_version" ]; then
        echo "ttfx $current is already the newest stable release."
        return 0
    fi

    echo "Upgrading ttfx from ${current:-not installed} to $latest_version..."
    cargo install \
        --git "$TTFX_REPOSITORY" \
        --tag "$latest_tag" \
        --locked \
        --force \
        --root "$INSTALL_ROOT" \
        ttfx
    verify_install "$latest_version"
}

case "${1:-install}" in
    install)
        install_pinned
        ;;
    upgrade)
        upgrade_latest
        ;;
    -h | --help | help)
        usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage >&2
        exit 1
        ;;
esac
