#!/bin/bash

set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
DPMS_LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall/dpms.log"
DPMS_LOG_CLEANUP_DAYS=14
DPMS_LOG_CLEANUP_MAX_FILES=10

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

if ! [[ "${DPMS_LOG_CLEANUP_DAYS:-}" =~ ^[0-9]+$ ]]; then
    DPMS_LOG_CLEANUP_DAYS=0
fi
if ! [[ "${DPMS_LOG_CLEANUP_MAX_FILES:-}" =~ ^[0-9]+$ ]]; then
    DPMS_LOG_CLEANUP_MAX_FILES=0
fi

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "%s [dpms-log-cleanup] %s\n" "$ts" "$*" >&2
}

if [ -z "${DPMS_LOG_FILE:-}" ]; then
    log "DPMS_LOG_FILE is empty; skipping."
    exit 0
fi

log_dir="$(dirname "$DPMS_LOG_FILE")"
base="$(basename "$DPMS_LOG_FILE")"

if [ ! -d "$log_dir" ]; then
    exit 0
fi

if [ "${DPMS_LOG_CLEANUP_DAYS:-0}" -gt 0 ]; then
    find "$log_dir" -maxdepth 1 -type f -name "${base}.*" \
        -mtime "+$DPMS_LOG_CLEANUP_DAYS" -exec rm -f -- {} + 2>/dev/null || true
fi

if [ "${DPMS_LOG_CLEANUP_MAX_FILES:-0}" -gt 0 ]; then
    mapfile -t files < <(ls -1t "${log_dir}/${base}."* 2>/dev/null || true)
    if [ "${#files[@]}" -gt "$DPMS_LOG_CLEANUP_MAX_FILES" ]; then
        for ((i=DPMS_LOG_CLEANUP_MAX_FILES; i<${#files[@]}; i++)); do
            rm -f -- "${files[$i]}"
        done
    fi
fi
