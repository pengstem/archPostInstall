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

is_non_negative_int() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

reset_dpms_config() {
    DPMS_APPS=()
    DPMS_VERBOSE=1
    DPMS_START_WAIT_SEC=15
    DPMS_START_RETRIES=3
    DPMS_KILL_WAIT_SEC=6
}

# dpms_defaults is a sourced config DSL; assignments are consumed after load_dpms_config.
# shellcheck disable=SC2034
dpms_defaults() {
    while [ "$#" -gt 0 ]; do
        if [ "$#" -lt 2 ]; then
            echo "Error: missing value for option $1" >&2
            return 1
        fi
        case "$1" in
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
    local action="restart"

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
            --action)
                action="$2"
                ;;
            *)
                echo "Error: unknown dpms_app option $1" >&2
                return 1
                ;;
        esac
        shift 2
    done

    if [ -z "$name" ] || [ -z "$match" ]; then
        echo "Error: dpms_app requires --name and --match." >&2
        return 1
    fi

    DPMS_APPS+=("${name}${DPMS_RECORD_SEP}${match}${DPMS_RECORD_SEP}${start}${DPMS_RECORD_SEP}${action}")
}

validate_dpms_config() {
    local require_apps="${1:-1}"
    local -A seen_names=()
    local record name match start action

    if [ "$require_apps" -eq 1 ] && [ "${#DPMS_APPS[@]}" -eq 0 ]; then
        echo "Error: at least one dpms_app entry is required." >&2
        return 1
    fi

    for record in "${DPMS_APPS[@]}"; do
        IFS="$DPMS_RECORD_SEP" read -r name match start action <<< "$record"
        if [ -z "$name" ] || [ -z "$match" ]; then
            echo "Error: invalid dpms_app entry in config." >&2
            return 1
        fi
        case "$action" in
            restart|start)
                if [ -z "$start" ]; then
                    echo "Error: $action action requires --start for $name." >&2
                    return 1
                fi
                ;;
            stop)
                ;;
            *)
                echo "Error: unsupported app action '$action' for $name." >&2
                return 1
                ;;
        esac
        if [ -n "${seen_names[$name]+x}" ]; then
            echo "Error: duplicate DPMS app name '$name'." >&2
            return 1
        fi
        seen_names[$name]=1
    done

    for value_name in \
        DPMS_VERBOSE \
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

dpms_log() {
    if [ "${DPMS_VERBOSE:-1}" -ge 1 ]; then
        printf "[dpms] %s\n" "$*" >&2
    fi
}

acquire_lock() {
    local lock_file="$1"

    mkdir -p "$(dirname "$lock_file")"

    exec 9>"$lock_file"
    if ! flock -n 9; then
        dpms_log "Another DPMS instance is running; skipping."
        exit 0
    fi
}
