#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# shellcheck source=scripts/gnome/dpms-common.sh
. "$SCRIPT_DIR/dpms-common.sh"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall"
STATE_FILE="$STATE_DIR/dpms.state"
LOCK_FILE="$STATE_DIR/dpms.lock"
LOCK_DIR="$STATE_DIR/dpms.lock.d"
DISPLAY_OFF_MODE=1

usage() {
    cat <<'EOF'
Usage: dpms-toggle [--on|--off|--toggle]

--toggle   Toggle display power (default)
--off      Force display off
--on       Force display on and restore apps
EOF
}

case "${1:-}" in
    -h|--help|help)
        usage
        exit 0
        ;;
esac

setup_runtime_env
load_dpms_config "$CONFIG_FILE" required 1
dpms_init_log "dpms-toggle"
acquire_lock "$LOCK_FILE" "$LOCK_DIR"

require_cmd busctl

is_match_running() {
    local match="$1"
    pgrep -f -i -- "$match" >/dev/null 2>&1
}

wait_for_exit() {
    local match="$1"
    local timeout="$2"
    local elapsed=0

    while is_match_running "$match"; do
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 0
}

wait_for_start() {
    local match="$1"
    local timeout="$2"
    local elapsed=0

    while ! is_match_running "$match"; do
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 0
}

run_background() {
    local cmd="$1"

    if [ -z "$cmd" ]; then
        return 0
    fi

    dpms_log "Executing: $cmd"
    nohup /bin/bash -lc "exec 9>&-; $cmd" >/dev/null 2>&1 &
}

kill_match() {
    local match="$1"

    if ! is_match_running "$match"; then
        return 1
    fi

    dpms_log "Sending TERM to: $match"
    pkill -TERM -f -i -- "$match" >/dev/null 2>&1 || true

    if wait_for_exit "$match" "$DPMS_KILL_WAIT_SEC"; then
        return 0
    fi

    dpms_log "Sending KILL to: $match"
    pkill -KILL -f -i -- "$match" >/dev/null 2>&1 || true
    wait_for_exit "$match" 2 || true

    if is_match_running "$match"; then
        dpms_log "Warning: process still running after KILL: $match"
        return 1
    fi

    return 0
}

stop_app() {
    local name="$1"
    local match="$2"
    local stop_cmd="$3"

    if ! is_match_running "$match"; then
        dpms_log "Not running: $name"
        return 1
    fi

    dpms_log "Stopping $name"

    if [ -n "$stop_cmd" ]; then
        run_background "$stop_cmd"
        if wait_for_exit "$match" "$DPMS_KILL_WAIT_SEC"; then
            dpms_log "$name stopped via stop command."
            return 0
        fi
    fi

    kill_match "$match" || true
    if is_match_running "$match"; then
        dpms_log "Warning: $name is still running."
        return 1
    fi

    dpms_log "$name stopped."
    return 0
}

ensure_app_started() {
    local name="$1"
    local match="$2"
    local start_cmd="$3"
    local attempt=1

    if is_match_running "$match"; then
        return 0
    fi

    while [ "$attempt" -le "$DPMS_START_RETRIES" ]; do
        dpms_log "Starting $name (attempt $attempt)"
        run_background "$start_cmd"
        if wait_for_start "$match" "$DPMS_START_WAIT_SEC"; then
            dpms_log "$name started."
            return 0
        fi
        attempt=$((attempt + 1))
    done

    dpms_log "Error: failed to start $name."
    return 1
}

write_state() {
    local tmp_file

    if [ "$#" -eq 0 ]; then
        rm -f "$STATE_FILE"
        return 0
    fi

    mkdir -p "$STATE_DIR"
    tmp_file="$(mktemp "$STATE_DIR/dpms.state.XXXXXX")"

    while [ "$#" -gt 0 ]; do
        printf "%s\n" "$1" >> "$tmp_file"
        shift
    done

    mv "$tmp_file" "$STATE_FILE"
}

read_state_map() {
    local -n ref="$1"
    local key

    for key in "${!ref[@]}"; do
        unset "ref[$key]"
    done
    if [ ! -f "$STATE_FILE" ]; then
        return 0
    fi

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            ref["$line"]=1
        fi
    done < "$STATE_FILE"
}

get_display_mode() {
    local mode

    mode="$(busctl --user get-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode \
        2>/dev/null | awk '{print $2}' || true)"

    if ! [[ "$mode" =~ ^[0-9]+$ ]]; then
        dpms_log "Warning: unable to read PowerSaveMode; assuming display on."
        printf "0\n"
        return 0
    fi

    printf "%s\n" "$mode"
}

is_display_on() {
    [ "$(get_display_mode)" -eq 0 ]
}

set_display_mode() {
    local mode="$1"

    dpms_log "Setting PowerSaveMode to $mode"
    if ! busctl --user set-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i "$mode" \
        >/dev/null 2>&1; then
        dpms_log "Warning: failed to set PowerSaveMode to $mode"
        return 1
    fi

    return 0
}

dpms_off() {
    local -a app_names_to_restore=()
    local record app_name app_match app_stop app_policy kill_name kill_match

    if ! is_display_on; then
        dpms_log "Display already off."
        return 0
    fi

    for record in "${DPMS_APPS[@]}"; do
        IFS="$DPMS_RECORD_SEP" read -r app_name app_match _ app_stop app_policy <<< "$record"
        if [ "$app_policy" = "on_only" ]; then
            continue
        fi
        if is_match_running "$app_match"; then
            if [ "$app_policy" = "running" ]; then
                app_names_to_restore+=("$app_name")
            fi
            stop_app "$app_name" "$app_match" "$app_stop" || true
        fi
    done

    for record in "${DPMS_KILL_ONLY_APPS[@]}"; do
        IFS="$DPMS_RECORD_SEP" read -r kill_name kill_match <<< "$record"
        if is_match_running "$kill_match"; then
            dpms_log "Stopping $kill_name (no reopen)"
            kill_match "$kill_match" || true
        fi
    done

    write_state "${app_names_to_restore[@]}"

    if ! set_display_mode "$DISPLAY_OFF_MODE"; then
        dpms_log "Warning: display state save failed; continuing."
    fi

    dpms_log "Display off."
}

dpms_on() {
    local -A recorded_running=()
    local record app_name app_match app_start app_policy should_restore

    if ! is_display_on; then
        set_display_mode 0 || true
    else
        dpms_log "Display already on."
    fi

    read_state_map recorded_running

    if [ "$DPMS_REOPEN_DELAY_SEC" -gt 0 ] && [ "${#DPMS_APPS[@]}" -gt 0 ]; then
        sleep "$DPMS_REOPEN_DELAY_SEC"
    fi

    for record in "${DPMS_APPS[@]}"; do
        IFS="$DPMS_RECORD_SEP" read -r app_name app_match app_start _ app_policy <<< "$record"
        should_restore=0
        case "$app_policy" in
            always|on_only)
                should_restore=1
                ;;
            running)
                if [ -n "${recorded_running[$app_name]+x}" ]; then
                    should_restore=1
                fi
                ;;
        esac

        if [ "$should_restore" -eq 1 ]; then
            ensure_app_started "$app_name" "$app_match" "$app_start" || true
        fi
    done

    rm -f "$STATE_FILE"
    dpms_log "Display on."
}

case "${1:-}" in
    --off)
        dpms_off
        ;;
    --on)
        dpms_on
        ;;
    --toggle|"")
        if is_display_on; then
            dpms_off
        else
            dpms_on
        fi
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
esac
