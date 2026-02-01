#!/bin/bash
# dpms-common.sh - Shared utilities for DPMS automation scripts
# This file should be sourced, not executed directly.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# --- Environment Setup ---
# Consolidates XDG_RUNTIME_DIR and DBUS setup from dpms-toggle.sh:50-56
setup_runtime_env() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
    fi
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi
}

# --- Command Validation ---
# Consolidates require_cmd from dpms-toggle.sh:86-91 and dpms-lock-monitor.sh:16-21
require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command not found: $1" >&2
        exit 1
    fi
}

# --- Session ID Resolution ---
# Consolidates get_session_id from dpms-lock-monitor.sh:23-37
# and get_logind_session_id from dpms-toggle.sh:407-421
get_session_id() {
    local session_id="${XDG_SESSION_ID:-}"
    if [ -n "$session_id" ]; then
        echo "$session_id"
        return 0
    fi
    if command -v loginctl >/dev/null 2>&1; then
        session_id="$(loginctl list-sessions --no-legend 2>/dev/null | \
            awk -v user="$USER" '$3==user {print $1; exit}')"
        if [ -n "$session_id" ]; then
            echo "$session_id"
            return 0
        fi
    fi
    return 1
}

# --- Logging ---
# Parameterized log function for all DPMS scripts
# Usage: dpms_log "tag" "message"
dpms_log() {
    local tag="$1"
    shift
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "%s [%s] %s\n" "$ts" "$tag" "$*" >&2
}

# --- Array Validation ---
# Consolidates array length checks from dpms-toggle.sh:95-124
# Usage: validate_parallel_arrays "base_name" base_len "arr1_name" arr1_len ...
validate_parallel_arrays() {
    local base_name="$1"
    local base_len="$2"
    shift 2

    while [ $# -ge 2 ]; do
        local arr_name="$1"
        local arr_len="$2"
        shift 2

        if [ "$arr_len" -gt 0 ] && [ "$arr_len" -ne "$base_len" ]; then
            echo "Error: $arr_name length ($arr_len) must match $base_name ($base_len)." >&2
            exit 1
        fi
    done
}
