#!/bin/bash
# dpms-common.sh - Shared utilities for DPMS automation scripts
# This file should be sourced, not executed directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: this script should be sourced, not executed directly." >&2
    exit 1
fi

DPMS_RECORD_SEP=$'\037'

setup_runtime_env() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
    fi

    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: required command not found: $1" >&2
        exit 1
    fi
}

get_session_id() {
    local session_id="${XDG_SESSION_ID:-}"

    if [ -n "$session_id" ]; then
        printf "%s\n" "$session_id"
        return 0
    fi

    if command -v loginctl >/dev/null 2>&1; then
        session_id="$(loginctl list-sessions --no-legend 2>/dev/null | \
            awk -v user="$USER" '$3 == user { print $1; exit }')"
        if [ -n "$session_id" ]; then
            printf "%s\n" "$session_id"
            return 0
        fi
    fi

    return 1
}

is_non_negative_int() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

reset_dpms_config() {
    DPMS_APPS=()
    DPMS_KILL_ONLY_APPS=()
    DPMS_POWER_BACKEND="auto"
    DPMS_POWER_BACKEND_RESOLVED=""
    DPMS_PROFILE_ON="balanced"
    DPMS_PROFILE_OFF="power-saver"
    DPMS_PROFILE_OFF_SSH="balanced"
    DPMS_SWITCH_POWER=1
    DPMS_TLP_USE_SUDO=1
    DPMS_VERBOSE=1
    DPMS_LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall/dpms.log"
    DPMS_LOG_MAX_BYTES=1048576
    DPMS_LOG_KEEP=3
    DPMS_REOPEN_DELAY_SEC=2
    DPMS_START_WAIT_SEC=15
    DPMS_START_RETRIES=3
    DPMS_KILL_WAIT_SEC=6
}

dpms_defaults() {
    while [ "$#" -gt 0 ]; do
        if [ "$#" -lt 2 ]; then
            echo "Error: missing value for option $1" >&2
            return 1
        fi
        case "$1" in
            --power-backend)
                DPMS_POWER_BACKEND="$2"
                ;;
            --profile-on)
                DPMS_PROFILE_ON="$2"
                ;;
            --profile-off)
                DPMS_PROFILE_OFF="$2"
                ;;
            --profile-off-ssh)
                DPMS_PROFILE_OFF_SSH="$2"
                ;;
            --switch-power)
                DPMS_SWITCH_POWER="$2"
                ;;
            --tlp-use-sudo)
                DPMS_TLP_USE_SUDO="$2"
                ;;
            --log-file)
                DPMS_LOG_FILE="$2"
                ;;
            --log-max-bytes)
                DPMS_LOG_MAX_BYTES="$2"
                ;;
            --log-keep)
                DPMS_LOG_KEEP="$2"
                ;;
            --reopen-delay)
                DPMS_REOPEN_DELAY_SEC="$2"
                ;;
            --start-wait)
                DPMS_START_WAIT_SEC="$2"
                ;;
            --start-retries)
                DPMS_START_RETRIES="$2"
                ;;
            --kill-wait)
                DPMS_KILL_WAIT_SEC="$2"
                ;;
            --verbose)
                DPMS_VERBOSE="$2"
                ;;
            *)
                echo "Error: unknown dpms_defaults option $1" >&2
                return 1
                ;;
        esac
        shift 2
    done
}

dpms_app() {
    local name=""
    local match=""
    local start=""
    local stop=""
    local policy="running"

    while [ "$#" -gt 0 ]; do
        if [ "$#" -lt 2 ]; then
            echo "Error: missing value for option $1" >&2
            return 1
        fi
        case "$1" in
            --name)
                name="$2"
                ;;
            --match)
                match="$2"
                ;;
            --start)
                start="$2"
                ;;
            --stop)
                stop="$2"
                ;;
            --policy)
                policy="$2"
                ;;
            *)
                echo "Error: unknown dpms_app option $1" >&2
                return 1
                ;;
        esac
        shift 2
    done

    if [ -z "$name" ] || [ -z "$match" ] || [ -z "$start" ]; then
        echo "Error: dpms_app requires --name, --match, and --start." >&2
        return 1
    fi

    DPMS_APPS+=("${name}${DPMS_RECORD_SEP}${match}${DPMS_RECORD_SEP}${start}${DPMS_RECORD_SEP}${stop}${DPMS_RECORD_SEP}${policy}")
}

dpms_kill_only() {
    local name=""
    local match=""

    while [ "$#" -gt 0 ]; do
        if [ "$#" -lt 2 ]; then
            echo "Error: missing value for option $1" >&2
            return 1
        fi
        case "$1" in
            --name)
                name="$2"
                ;;
            --match)
                match="$2"
                ;;
            *)
                echo "Error: unknown dpms_kill_only option $1" >&2
                return 1
                ;;
        esac
        shift 2
    done

    if [ -z "$name" ] || [ -z "$match" ]; then
        echo "Error: dpms_kill_only requires --name and --match." >&2
        return 1
    fi

    DPMS_KILL_ONLY_APPS+=("${name}${DPMS_RECORD_SEP}${match}")
}

validate_dpms_config() {
    local require_apps="${1:-1}"
    local -A seen_names=()
    local record name match start stop policy

    if [ "$require_apps" -eq 1 ] && [ "${#DPMS_APPS[@]}" -eq 0 ]; then
        echo "Error: at least one dpms_app entry is required." >&2
        return 1
    fi

    for record in "${DPMS_APPS[@]}"; do
        IFS="$DPMS_RECORD_SEP" read -r name match start stop policy <<< "$record"
        if [ -z "$name" ] || [ -z "$match" ] || [ -z "$start" ]; then
            echo "Error: invalid dpms_app entry in config." >&2
            return 1
        fi
        case "$policy" in
            running|always|on_only)
                ;;
            *)
                echo "Error: unsupported app policy '$policy' for $name." >&2
                return 1
                ;;
        esac
        if [ -n "${seen_names[$name]+x}" ]; then
            echo "Error: duplicate DPMS app name '$name'." >&2
            return 1
        fi
        seen_names[$name]=1
    done

    for record in "${DPMS_KILL_ONLY_APPS[@]}"; do
        IFS="$DPMS_RECORD_SEP" read -r name match <<< "$record"
        if [ -z "$name" ] || [ -z "$match" ]; then
            echo "Error: invalid dpms_kill_only entry in config." >&2
            return 1
        fi
        if [ -n "${seen_names[$name]+x}" ]; then
            echo "Error: duplicate DPMS item name '$name'." >&2
            return 1
        fi
        seen_names[$name]=1
    done

    case "$DPMS_POWER_BACKEND" in
        auto|tlp|ppd)
            ;;
        *)
            echo "Error: invalid DPMS power backend '$DPMS_POWER_BACKEND'." >&2
            return 1
            ;;
    esac

    for value_name in \
        DPMS_SWITCH_POWER \
        DPMS_TLP_USE_SUDO \
        DPMS_VERBOSE \
        DPMS_LOG_MAX_BYTES \
        DPMS_LOG_KEEP \
        DPMS_REOPEN_DELAY_SEC \
        DPMS_START_WAIT_SEC \
        DPMS_START_RETRIES \
        DPMS_KILL_WAIT_SEC; do
        if ! is_non_negative_int "${!value_name}"; then
            echo "Error: $value_name must be a non-negative integer." >&2
            return 1
        fi
    done
}

load_dpms_config() {
    local config_file="$1"
    local file_mode="${2:-required}"
    local require_apps="${3:-1}"

    reset_dpms_config

    if [ ! -f "$config_file" ]; then
        if [ "$file_mode" = "optional" ]; then
            validate_dpms_config "$require_apps"
            return $?
        fi
        echo "Error: config file not found: $config_file" >&2
        return 1
    fi

    # shellcheck source=/dev/null
    . "$config_file"
    validate_dpms_config "$require_apps"
}

dpms_init_log() {
    DPMS_LOG_TAG="$1"
}

dpms_rotate_log() {
    local log_file="${DPMS_LOG_FILE:-}"
    local max_bytes="${DPMS_LOG_MAX_BYTES:-0}"
    local keep="${DPMS_LOG_KEEP:-0}"
    local size idx

    if [ -z "$log_file" ] || ! is_non_negative_int "$max_bytes" || \
       ! is_non_negative_int "$keep" || [ "$max_bytes" -le 0 ] || [ "$keep" -le 0 ] || \
       [ ! -f "$log_file" ]; then
        return 0
    fi

    size="$(wc -c < "$log_file" 2>/dev/null || echo 0)"
    if [ "$size" -lt "$max_bytes" ]; then
        return 0
    fi

    rm -f "${log_file}.${keep}"
    for ((idx=keep; idx>=2; idx--)); do
        if [ -f "${log_file}.$((idx - 1))" ]; then
            mv "${log_file}.$((idx - 1))" "${log_file}.${idx}"
        fi
    done
    mv "$log_file" "${log_file}.1"
}

dpms_log() {
    local ts msg

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    msg="$ts [${DPMS_LOG_TAG:-dpms}] $*"

    if [ -n "${DPMS_LOG_FILE:-}" ]; then
        mkdir -p "$(dirname "$DPMS_LOG_FILE")"
        dpms_rotate_log
        printf "%s\n" "$msg" >> "$DPMS_LOG_FILE"
    fi

    if [ "${DPMS_VERBOSE:-1}" -ge 1 ]; then
        printf "%s\n" "$msg" >&2
    fi
}

dpms_have_tlp() {
    command -v tlpctl >/dev/null 2>&1 || command -v tlp >/dev/null 2>&1
}

dpms_resolve_power_backend() {
    if [ -n "${DPMS_POWER_BACKEND_RESOLVED:-}" ]; then
        printf "%s\n" "$DPMS_POWER_BACKEND_RESOLVED"
        return 0
    fi

    case "$DPMS_POWER_BACKEND" in
        tlp)
            if command -v tlpctl >/dev/null 2>&1; then
                DPMS_POWER_BACKEND_RESOLVED="tlpctl"
            elif command -v tlp >/dev/null 2>&1; then
                DPMS_POWER_BACKEND_RESOLVED="tlp"
            else
                DPMS_POWER_BACKEND_RESOLVED="none"
            fi
            ;;
        ppd)
            if command -v powerprofilesctl >/dev/null 2>&1; then
                DPMS_POWER_BACKEND_RESOLVED="ppd"
            else
                DPMS_POWER_BACKEND_RESOLVED="none"
            fi
            ;;
        auto)
            if command -v tlpctl >/dev/null 2>&1; then
                DPMS_POWER_BACKEND_RESOLVED="tlpctl"
            elif command -v tlp >/dev/null 2>&1; then
                DPMS_POWER_BACKEND_RESOLVED="tlp"
            elif command -v powerprofilesctl >/dev/null 2>&1; then
                DPMS_POWER_BACKEND_RESOLVED="ppd"
            else
                DPMS_POWER_BACKEND_RESOLVED="none"
            fi
            ;;
    esac

    printf "%s\n" "$DPMS_POWER_BACKEND_RESOLVED"
}

dpms_set_tlp_profile() {
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

acquire_lock() {
    local lock_file="$1"
    local lock_dir="$2"

    mkdir -p "$(dirname "$lock_file")"

    if command -v flock >/dev/null 2>&1; then
        exec 9>"$lock_file"
        if ! flock -n 9; then
            dpms_log "Another DPMS instance is running; skipping."
            exit 0
        fi
        return 0
    fi

    if ! mkdir "$lock_dir" 2>/dev/null; then
        dpms_log "Another DPMS instance is running; skipping."
        exit 0
    fi

    trap 'rmdir "'"$lock_dir"'" 2>/dev/null || true' EXIT
}
