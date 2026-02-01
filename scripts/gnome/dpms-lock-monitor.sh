#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

LOG_TAG="dpms-lock-monitor"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "%s [%s] %s\n" "$ts" "$LOG_TAG" "$*" >&2
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log "Error: required command not found: $1"
        exit 1
    fi
}

get_session_id() {
    local session_id="${XDG_SESSION_ID:-}"
    if [ -n "$session_id" ]; then
        echo "$session_id"
        return 0
    fi
    if command -v loginctl >/dev/null 2>&1; then
        session_id="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v user="$USER" '$3==user {print $1; exit}')"
        if [ -n "$session_id" ]; then
            echo "$session_id"
            return 0
        fi
    fi
    return 1
}

get_session_path() {
    local session_id="$1"
    loginctl show-session "$session_id" -p Path --value 2>/dev/null || true
}

get_locked_hint() {
    local session_id="$1"
    loginctl show-session "$session_id" -p LockedHint --value 2>/dev/null || true
}

monitor_lock_state() {
    local session_id session_path locked_hint

    session_id="$(get_session_id)" || {
        log "Error: unable to determine session id."
        exit 1
    }
    session_path="$(get_session_path "$session_id")"
    if [ -z "$session_path" ]; then
        log "Error: unable to determine session path for id $session_id."
        exit 1
    fi

    locked_hint="$(get_locked_hint "$session_id")"
    if [ "$locked_hint" = "yes" ] || [ "$locked_hint" = "true" ]; then
        log "Session already locked; running dpms-toggle --off."
        if ! "$SCRIPT_DIR/dpms-toggle.sh" --off; then
            log "Warning: dpms-toggle --off failed."
        fi
    fi

    log "Watching lock state on $session_path."
    gdbus monitor --system --dest org.freedesktop.login1 --object-path "$session_path" | while IFS= read -r line; do
        if [[ "$line" == *"LockedHint"*"<true>"* ]]; then
            log "Lock detected; running dpms-toggle --off."
            if ! "$SCRIPT_DIR/dpms-toggle.sh" --off; then
                log "Warning: dpms-toggle --off failed."
            fi
        elif [[ "$line" == *"LockedHint"*"<false>"* ]]; then
            log "Unlock detected; running dpms-toggle --on."
            if ! "$SCRIPT_DIR/dpms-toggle.sh" --on; then
                log "Warning: dpms-toggle --on failed."
            fi
        fi
    done
}

require_cmd gdbus
require_cmd loginctl

monitor_lock_state
