#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

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

read_app_record() {
    local record="$1"
    IFS="$DPMS_RECORD_SEP" read -r APP_NAME APP_MATCH APP_START APP_STOP APP_POLICY <<< "$record"
}

read_kill_only_record() {
    local record="$1"
    IFS="$DPMS_RECORD_SEP" read -r KILL_NAME KILL_MATCH <<< "$record"
}

append_unique() {
    local -n ref="$1"
    local item="$2"
    local existing

    for existing in "${ref[@]}"; do
        if [ "$existing" = "$item" ]; then
            return 0
        fi
    done

    ref+=("$item")
}

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
        dpms_log "Already running: $name"
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
    mkdir -p "$STATE_DIR"
    : > "$STATE_FILE"

    while [ "$#" -gt 0 ]; do
        printf "%s\n" "$1" >> "$STATE_FILE"
        shift
    done
}

read_state() {
    local -n ref="$1"

    ref=()
    if [ ! -f "$STATE_FILE" ]; then
        return 0
    fi

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            append_unique ref "$line"
        fi
    done < "$STATE_FILE"
}

clear_state() {
    rm -f "$STATE_FILE"
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

has_ssh_session() {
    if command -v ss >/dev/null 2>&1; then
        if ss -Htn state established '( sport = :22 )' 2>/dev/null | grep -q .; then
            return 0
        fi
    fi

    if command -v who >/dev/null 2>&1; then
        if who | awk '{print $NF}' | grep -E '\([^)]*\)' | grep -v '(:0)' | grep -q .; then
            return 0
        fi
    fi

    return 1
}

resolve_power_backend() {
    case "$DPMS_POWER_BACKEND" in
        tlp)
            if command -v tlpctl >/dev/null 2>&1; then
                printf "tlpctl\n"
            elif command -v tlp >/dev/null 2>&1; then
                printf "tlp\n"
            else
                printf "none\n"
            fi
            ;;
        ppd)
            if command -v powerprofilesctl >/dev/null 2>&1; then
                printf "ppd\n"
            else
                printf "none\n"
            fi
            ;;
        auto)
            if command -v tlpctl >/dev/null 2>&1; then
                printf "tlpctl\n"
            elif command -v tlp >/dev/null 2>&1; then
                printf "tlp\n"
            elif command -v powerprofilesctl >/dev/null 2>&1; then
                printf "ppd\n"
            else
                printf "none\n"
            fi
            ;;
    esac
}

set_tlp_profile() {
    local profile="$1"

    if command -v tlpctl >/dev/null 2>&1; then
        tlpctl set "$profile" >/dev/null 2>&1
        return $?
    fi

    if ! command -v tlp >/dev/null 2>&1; then
        return 1
    fi

    if [ "${DPMS_TLP_USE_SUDO:-1}" -eq 1 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            return 1
        fi
        sudo -n tlp "$profile" >/dev/null 2>&1
        return $?
    fi

    tlp "$profile" >/dev/null 2>&1
}

apply_power_profile() {
    local profile="$1"
    local backend

    if [ "${DPMS_SWITCH_POWER:-1}" -ne 1 ] || [ -z "$profile" ]; then
        return 0
    fi

    backend="$(resolve_power_backend)"
    case "$backend" in
        tlpctl|tlp)
            dpms_log "Switching power profile via TLP: $profile"
            if ! set_tlp_profile "$profile"; then
                dpms_log "Warning: failed to set TLP profile: $profile"
            fi
            ;;
        ppd)
            dpms_log "Switching power profile via powerprofilesctl: $profile"
            if ! powerprofilesctl set "$profile" >/dev/null 2>&1; then
                dpms_log "Warning: failed to set power profile: $profile"
            fi
            ;;
        none)
            dpms_log "No supported power backend found; skipping profile switch."
            ;;
    esac
}

find_app_record() {
    local target_name="$1"
    local record

    for record in "${DPMS_APPS[@]}"; do
        read_app_record "$record"
        if [ "$APP_NAME" = "$target_name" ]; then
            printf "%s\n" "$record"
            return 0
        fi
    done

    return 1
}

collect_restore_targets() {
    local -n ref="$1"
    local -a recorded=()
    local record

    read_state recorded
    ref=("${recorded[@]}")

    for record in "${DPMS_APPS[@]}"; do
        read_app_record "$record"
        case "$APP_POLICY" in
            always|on_only)
                append_unique ref "$APP_NAME"
                ;;
        esac
    done
}

dpms_off() {
    local -a recorded_running=()
    local record

    if ! is_display_on; then
        dpms_log "Display already off."
        return 0
    fi

    for record in "${DPMS_APPS[@]}"; do
        read_app_record "$record"
        if [ "$APP_POLICY" = "on_only" ]; then
            continue
        fi
        if is_match_running "$APP_MATCH"; then
            if [ "$APP_POLICY" = "running" ]; then
                append_unique recorded_running "$APP_NAME"
            fi
            stop_app "$APP_NAME" "$APP_MATCH" "$APP_STOP" || true
        else
            dpms_log "Not running: $APP_NAME"
        fi
    done

    for record in "${DPMS_KILL_ONLY_APPS[@]}"; do
        read_kill_only_record "$record"
        if is_match_running "$KILL_MATCH"; then
            dpms_log "Stopping $KILL_NAME (no reopen)"
            kill_match "$KILL_MATCH" || true
        fi
    done

    write_state "${recorded_running[@]}"

    if ! set_display_mode "$DISPLAY_OFF_MODE"; then
        dpms_log "Warning: display state save failed; continuing."
    fi

    if has_ssh_session; then
        apply_power_profile "$DPMS_PROFILE_OFF_SSH"
    else
        apply_power_profile "$DPMS_PROFILE_OFF"
    fi

    dpms_log "Display off."
}

dpms_on() {
    local -a restore_targets=()
    local record name

    if ! is_display_on; then
        set_display_mode 0 || true
    else
        dpms_log "Display already on."
    fi

    apply_power_profile "$DPMS_PROFILE_ON"
    collect_restore_targets restore_targets

    if [ "$DPMS_REOPEN_DELAY_SEC" -gt 0 ] && [ "${#restore_targets[@]}" -gt 0 ]; then
        sleep "$DPMS_REOPEN_DELAY_SEC"
    fi

    for name in "${restore_targets[@]}"; do
        record="$(find_app_record "$name" || true)"
        if [ -z "$record" ]; then
            dpms_log "Skipping unknown app in state: $name"
            continue
        fi
        read_app_record "$record"
        ensure_app_started "$APP_NAME" "$APP_MATCH" "$APP_START" || true
    done

    clear_state
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
