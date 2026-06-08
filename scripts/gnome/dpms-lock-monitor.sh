#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# shellcheck source=scripts/gnome/dpms-common.sh
. "$SCRIPT_DIR/dpms-common.sh"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"

setup_runtime_env
load_dpms_config "$CONFIG_FILE" optional 0
dpms_init_log "dpms-lock-monitor"

get_session_path() {
    local session_id="$1"
    # loginctl show-session -p Path may return empty on some systemd versions
    # Use D-Bus GetSession method instead
    busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager GetSession s "$session_id" 2>/dev/null | \
        sed -n 's/^o "\(.*\)"$/\1/p'
}

get_locked_hint() {
    local session_id="$1"
    loginctl show-session "$session_id" -p LockedHint --value 2>/dev/null || true
}

monitor_lock_state() {
    local session_id session_path locked_hint

    session_id="$(get_session_id)" || {
        dpms_log "Error: unable to determine session id."
        exit 1
    }
    session_path="$(get_session_path "$session_id")"
    if [ -z "$session_path" ]; then
        dpms_log "Error: unable to determine session path for id $session_id."
        exit 1
    fi

    locked_hint="$(get_locked_hint "$session_id")"
    if [ "$locked_hint" = "yes" ] || [ "$locked_hint" = "true" ]; then
        dpms_log "Session already locked; running dpms-toggle --off."
        if ! "$SCRIPT_DIR/dpms-toggle.sh" --off; then
            dpms_log "Warning: dpms-toggle --off failed."
        fi
    fi

    dpms_log "Watching lock state on $session_path."
    gdbus monitor --system --dest org.freedesktop.login1 --object-path "$session_path" | while IFS= read -r line; do
        if [[ "$line" == *"LockedHint"*"<true>"* ]]; then
            dpms_log "Lock detected; running dpms-toggle --off."
            if ! "$SCRIPT_DIR/dpms-toggle.sh" --off; then
                dpms_log "Warning: dpms-toggle --off failed."
            fi
        elif [[ "$line" == *"LockedHint"*"<false>"* ]]; then
            dpms_log "Unlock detected; running dpms-toggle --on."
            if ! "$SCRIPT_DIR/dpms-toggle.sh" --on; then
                dpms_log "Warning: dpms-toggle --on failed."
            fi
        fi
    done
}

require_cmd gdbus
require_cmd loginctl
require_cmd busctl

monitor_lock_state
