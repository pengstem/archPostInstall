#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Source shared library
. "$SCRIPT_DIR/dpms-common.sh"

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

LOG_TAG="dpms-log-cleanup"

log() {
    dpms_log "$LOG_TAG" "$@"
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

deleted_count=0

if [ "${DPMS_LOG_CLEANUP_DAYS:-0}" -gt 0 ]; then
    while IFS= read -r -d '' file; do
        rm -f -- "$file"
        ((deleted_count++)) || true
    done < <(find "$log_dir" -maxdepth 1 -type f -name "${base}.*" \
        -mtime "+$DPMS_LOG_CLEANUP_DAYS" -print0 2>/dev/null)
fi

if [ "${DPMS_LOG_CLEANUP_MAX_FILES:-0}" -gt 0 ]; then
    mapfile -t files < <(ls -1t "${log_dir}/${base}."* 2>/dev/null || true)
    if [ "${#files[@]}" -gt "$DPMS_LOG_CLEANUP_MAX_FILES" ]; then
        for ((i=DPMS_LOG_CLEANUP_MAX_FILES; i<${#files[@]}; i++)); do
            rm -f -- "${files[$i]}"
            ((deleted_count++)) || true
        done
    fi
fi

if [ "$deleted_count" -gt 0 ]; then
    log "Deleted $deleted_count old log file(s)."
fi
