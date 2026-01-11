#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall"
STATE_FILE="$STATE_DIR/dpms.state"

DPMS_REOPEN_NAMES=("firefox" "wechat" "qq")
DPMS_KILL_MATCHES=("firefox" "/home/nastem/Applications/WeChat.AppImage" "/home/nastem/Applications/QQ.AppImage")
DPMS_REOPEN_COMMANDS=("firefox" "gtk-launch WeChat" "gtk-launch QQ")
DPMS_KEEP_PROCS=("kitty" "sparkle")
DPMS_POWER_PROFILE_ON="balanced"
DPMS_POWER_PROFILE_OFF="power-saver"
DPMS_POWER_PROFILE_OFF_SSH="power-saver"
DPMS_IDLE_MINUTES=15
DPMS_REOPEN_DELAY_SEC=2
DPMS_KILL_OTHER_GUI=0

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command not found: $1" >&2
        exit 1
    fi
}

require_cmd busctl

if [ "${#DPMS_REOPEN_NAMES[@]}" -ne "${#DPMS_KILL_MATCHES[@]}" ] || \
   [ "${#DPMS_REOPEN_NAMES[@]}" -ne "${#DPMS_REOPEN_COMMANDS[@]}" ]; then
    echo "Error: dpms.conf arrays must have the same length." >&2
    exit 1
fi

log() {
    printf "[dpms-toggle] %s\n" "$*"
}

get_dpms_mode() {
    busctl --user get-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode \
        | awk '{print $2}'
}

set_dpms_mode() {
    busctl --user set-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i "$1"
}

is_display_on() {
    [ "$(get_dpms_mode)" -eq 0 ]
}

has_ssh_session() {
    if command -v ss >/dev/null 2>&1; then
        if ss -Htn state established '( sport = :22 )' | grep -q .; then
            return 0
        fi
    fi

    if command -v who >/dev/null 2>&1; then
        if who | awk '{print $NF}' | grep -qE '\\([^)]*\\)' | grep -vq '(:0)'; then
            return 0
        fi
    fi

    return 1
}

get_power_profile() {
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl get 2>/dev/null || true
    fi
}

set_power_profile() {
    local profile="$1"
    if [ -z "$profile" ]; then
        return 0
    fi
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set "$profile" || true
    fi
}

save_state() {
    local reopen_list="$1"
    local profile_before="$2"

    mkdir -p "$STATE_DIR"
    {
        echo "REOPEN_APPS=\"$reopen_list\""
        echo "POWER_PROFILE_BEFORE=\"$profile_before\""
    } > "$STATE_FILE"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        # shellcheck source=/dev/null
        . "$STATE_FILE"
    fi
}

clear_state() {
    rm -f "$STATE_FILE"
}

kill_match() {
    local match="$1"
    if pgrep -f "$match" >/dev/null 2>&1; then
        pkill -TERM -f "$match" || true
        sleep 1
        if pgrep -f "$match" >/dev/null 2>&1; then
            pkill -KILL -f "$match" || true
        fi
    fi
}

run_command() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        return 0
    fi
    nohup bash -c "$cmd" >/dev/null 2>&1 &
}

maybe_log_other_gui() {
    if ! command -v gdbus >/dev/null 2>&1; then
        return 0
    fi

    local result
    result="$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \
        "global.get_window_actors().map(w => w.get_meta_window().get_wm_class()).join('\\n')")" || true

    local classes
    classes="$(echo "$result" | sed -n "s/^([^,]*, '\\(.*\\)')$/\\1/p")"
    if [ -z "$classes" ]; then
        return 0
    fi

    log "Running GUI classes:"
    printf "%s\n" "$classes" | while read -r cls; do
        [ -z "$cls" ] && continue
        log "  $cls"

        if [ "$DPMS_KILL_OTHER_GUI" -eq 0 ]; then
            continue
        fi

        local keep=0
        for keep_name in "${DPMS_KEEP_PROCS[@]}"; do
            if [ "${keep_name,,}" = "${cls,,}" ]; then
                keep=1
                break
            fi
        done
        if [ "$keep" -eq 1 ]; then
            continue
        fi

        log "Stopping GUI app (best-effort): $cls"
        pkill -TERM -x "$cls" >/dev/null 2>&1 || true
        pkill -TERM -f "$cls" >/dev/null 2>&1 || true
    done
}

dpms_off() {
    if ! is_display_on; then
        log "Display already off."
        return 0
    fi

    local reopen_apps=()
    local i name match

    for i in "${!DPMS_REOPEN_NAMES[@]}"; do
        name="${DPMS_REOPEN_NAMES[$i]}"
        match="${DPMS_KILL_MATCHES[$i]}"
        if pgrep -f "$match" >/dev/null 2>&1; then
            reopen_apps+=("$name")
            log "Stopping $name..."
            kill_match "$match"
        fi
    done

    maybe_log_other_gui

    local profile_before
    profile_before="$(get_power_profile)"

    set_dpms_mode 1

    if has_ssh_session; then
        set_power_profile "$DPMS_POWER_PROFILE_OFF_SSH"
    else
        set_power_profile "$DPMS_POWER_PROFILE_OFF"
    fi

    save_state "${reopen_apps[*]}" "$profile_before"
    log "Display off."
}

dpms_on() {
    if is_display_on; then
        log "Display already on."
    else
        set_dpms_mode 0
    fi

    load_state

    local profile_before="${POWER_PROFILE_BEFORE:-}"
    if [ -n "$profile_before" ]; then
        set_power_profile "$profile_before"
    else
        set_power_profile "$DPMS_POWER_PROFILE_ON"
    fi

    if [ -n "${REOPEN_APPS:-}" ]; then
        local reopen_list=()
        IFS=' ' read -r -a reopen_list <<< "$REOPEN_APPS"
        if [ "$DPMS_REOPEN_DELAY_SEC" -gt 0 ]; then
            sleep "$DPMS_REOPEN_DELAY_SEC"
        fi

        local i name cmd idx
        for name in "${reopen_list[@]}"; do
            idx=-1
            for i in "${!DPMS_REOPEN_NAMES[@]}"; do
                if [ "${DPMS_REOPEN_NAMES[$i]}" = "$name" ]; then
                    idx="$i"
                    break
                fi
            done
            if [ "$idx" -ge 0 ]; then
                cmd="${DPMS_REOPEN_COMMANDS[$idx]}"
                log "Starting $name..."
                run_command "$cmd"
            fi
        done
    fi

    clear_state
    log "Display on."
}

dpms_restore() {
    if [ ! -f "$STATE_FILE" ]; then
        return 0
    fi
    if is_display_on; then
        dpms_on
    fi
}

get_idle_seconds() {
    if ! command -v gdbus >/dev/null 2>&1; then
        return 1
    fi

    local raw
    raw="$(gdbus call --session --dest org.gnome.Mutter.IdleMonitor \
        --object-path /org/gnome/Mutter/IdleMonitor/Core \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null)" || return 1

    local ms
    ms="$(echo "$raw" | tr -cd '0-9')"
    if [ -z "$ms" ]; then
        return 1
    fi

    echo $((ms / 1000))
}

dpms_idle() {
    local idle_seconds
    idle_seconds="$(get_idle_seconds)" || {
        log "Idle monitor unavailable; skipping."
        return 0
    }

    local threshold=$((DPMS_IDLE_MINUTES * 60))
    if [ "$idle_seconds" -ge "$threshold" ]; then
        dpms_off
    fi
}

usage() {
    cat <<EOF
Usage: dpms-toggle [--on|--off|--toggle|--idle|--restore]

--toggle   Toggle display power (default)
--off      Force display off
--on       Force display on and restore apps
--idle     Turn off display if currently on (used by idle timer)
--restore  Restore apps if display is on and state exists
EOF
}

case "${1:-}" in
    --off)
        dpms_off
        ;;
    --on)
        dpms_on
        ;;
    --idle)
        dpms_idle
        ;;
    --restore)
        dpms_restore
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
