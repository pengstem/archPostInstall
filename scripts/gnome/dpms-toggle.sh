#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Source shared library
. "$SCRIPT_DIR/dpms-common.sh"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall"
STATE_FILE="$STATE_DIR/dpms.state"
TLP_STATE_FILE="$STATE_DIR/tlp.profile"
LOCK_FILE="$STATE_DIR/dpms.lock"
LOCK_DIR="$STATE_DIR/dpms.lock.d"

# Declare arrays as empty - config file is required
DPMS_REOPEN_NAMES=()
DPMS_KILL_MATCHES=()
DPMS_RUNNING_MATCHES=()
DPMS_WM_CLASSES=()
DPMS_REOPEN_COMMANDS=()
DPMS_REOPEN_ACTIVATE_COMMANDS=()
DPMS_CLOSE_COMMANDS=()
DPMS_KILL_ONLY_MATCHES=()
DPMS_KILL_ONLY_WM_CLASSES=()
DPMS_KEEP_PROCS=()

# Scalar defaults (safe to keep)
DPMS_FORCE_KILL_ON_CLOSE=1
DPMS_ALWAYS_REOPEN=0
DPMS_POWER_PROFILE_ON="balanced"
DPMS_POWER_PROFILE_OFF="power-saver"
DPMS_POWER_PROFILE_OFF_SSH="balanced"
DPMS_SKIP_POWER_PROFILE=0
DPMS_BRIGHTNESS_RESTORE=0
DPMS_BRIGHTNESS_DEVICE=""
DPMS_TLP_PROFILE_ON="balanced"
DPMS_TLP_PROFILE_OFF="power-saver"
DPMS_TLP_PROFILE_OFF_SSH="balanced"
DPMS_TLP_USE_SUDO=1
DPMS_REOPEN_DELAY_SEC=2
DPMS_START_WAIT_SEC=15
DPMS_START_RETRIES=3
DPMS_KILL_WAIT_SEC=6
DPMS_KILL_OTHER_GUI=1
DPMS_VERBOSE=2
DPMS_LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall/dpms.log"
DPMS_LOG_MAX_BYTES=1048576
DPMS_SUSPEND_IF_NO_SSH=0
DPMS_SUSPEND_DELAY_SEC=30

GNOME_EVAL_AVAILABLE=""  # Cache: "yes", "no", or "" (unknown)

# Setup runtime environment using shared library
setup_runtime_env

# Require config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    echo "Copy from configs/archpostinstall/dpms.conf and customize." >&2
    exit 1
fi
# shellcheck source=/dev/null
. "$CONFIG_FILE"

ensure_display_env() {
    # XDG_RUNTIME_DIR already set by setup_runtime_env() from dpms-common.sh
    if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
        local socket
        socket="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' 2>/dev/null | head -n 1)"
        if [ -n "$socket" ]; then
            WAYLAND_DISPLAY="$(basename "$socket")"
            export WAYLAND_DISPLAY
        fi
    fi
    if [ -z "${DISPLAY:-}" ] && [ -S /tmp/.X11-unix/X0 ]; then
        DISPLAY=":0"
        export DISPLAY
    fi
    if [ -z "${XAUTHORITY:-}" ] && [ -n "${DISPLAY:-}" ] && [ -f "$HOME/.Xauthority" ]; then
        XAUTHORITY="$HOME/.Xauthority"
        export XAUTHORITY
    fi
}

require_cmd busctl

# Validate required arrays are populated
if [ "${#DPMS_REOPEN_NAMES[@]}" -eq 0 ]; then
    echo "Error: DPMS_REOPEN_NAMES is empty. Check $CONFIG_FILE" >&2
    exit 1
fi

# Validate parallel arrays using shared library function
validate_parallel_arrays "DPMS_REOPEN_NAMES" "${#DPMS_REOPEN_NAMES[@]}" \
    "DPMS_KILL_MATCHES" "${#DPMS_KILL_MATCHES[@]}" \
    "DPMS_REOPEN_COMMANDS" "${#DPMS_REOPEN_COMMANDS[@]}" \
    "DPMS_RUNNING_MATCHES" "${#DPMS_RUNNING_MATCHES[@]}" \
    "DPMS_WM_CLASSES" "${#DPMS_WM_CLASSES[@]}" \
    "DPMS_REOPEN_ACTIVATE_COMMANDS" "${#DPMS_REOPEN_ACTIVATE_COMMANDS[@]}" \
    "DPMS_CLOSE_COMMANDS" "${#DPMS_CLOSE_COMMANDS[@]}"

validate_parallel_arrays "DPMS_KILL_ONLY_MATCHES" "${#DPMS_KILL_ONLY_MATCHES[@]}" \
    "DPMS_KILL_ONLY_WM_CLASSES" "${#DPMS_KILL_ONLY_WM_CLASSES[@]}"

log() {
    local ts msg
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    msg="$ts [dpms-toggle] $*"
    if [ -n "${DPMS_LOG_FILE:-}" ]; then
        mkdir -p "$(dirname "$DPMS_LOG_FILE")"
        rotate_log
        printf "%s\n" "$msg" >> "$DPMS_LOG_FILE"
    fi
    if [ "${DPMS_VERBOSE:-1}" -ge 1 ]; then
        printf "%s\n" "$msg" >&2
    fi
}

rotate_log() {
    local max_bytes="${DPMS_LOG_MAX_BYTES:-0}"
    if [ -z "${DPMS_LOG_FILE:-}" ] || [ "$max_bytes" -le 0 ]; then
        return 0
    fi
    if [ -f "$DPMS_LOG_FILE" ]; then
        local size ts
        size="$(wc -c < "$DPMS_LOG_FILE" 2>/dev/null || echo 0)"
        if [ "$size" -ge "$max_bytes" ]; then
            ts="$(date '+%Y%m%d-%H%M%S')"
            mv "$DPMS_LOG_FILE" "${DPMS_LOG_FILE}.${ts}" 2>/dev/null || true
        fi
    fi
}

acquire_lock() {
    mkdir -p "$STATE_DIR"
    if command -v flock >/dev/null 2>&1; then
        exec 9>"$LOCK_FILE"
        if ! flock -n 9; then
            log "Another dpms-toggle instance is running (flock busy); skipping."
            exit 0
        fi
        return 0
    fi
    # Fallback to mkdir lock only when flock is unavailable
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log "Another dpms-toggle instance is running; skipping."
        exit 0
    fi
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
}

acquire_lock

have_gdbus() {
    command -v gdbus >/dev/null 2>&1
}

gnome_eval_raw() {
    local js="$1"
    local output
    # Return early if we already know GNOME Shell Eval is unavailable
    if [ "$GNOME_EVAL_AVAILABLE" = "no" ]; then
        return 1
    fi
    if ! have_gdbus; then
        GNOME_EVAL_AVAILABLE="no"
        return 1
    fi
    output="$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval "$js" 2>/dev/null)" || {
        GNOME_EVAL_AVAILABLE="no"
        return 1
    }
    if ! echo "$output" | grep -q "^(true,"; then
        if [ "$GNOME_EVAL_AVAILABLE" != "no" ]; then
            log "GNOME Shell Eval unavailable (will not retry): $output"
            GNOME_EVAL_AVAILABLE="no"
        fi
        return 1
    fi
    GNOME_EVAL_AVAILABLE="yes"
    printf "%s" "$output"
}

get_wm_classes() {
    if ! have_gdbus; then
        return 1
    fi
    local result classes
    result="$(gnome_eval_raw "global.get_window_actors().map(w => w.get_meta_window().get_wm_class()).join('\\n')")" || return 1

    classes="$(echo "$result" | sed -n "s/^([^,]*, '\\(.*\\)')$/\\1/p")"
    if [ -n "$classes" ]; then
        printf "%s\n" "$classes"
    fi
}

wm_class_running() {
    local cls="$1"
    if [ -z "$cls" ]; then
        return 1
    fi
    get_wm_classes | awk '{print tolower($0)}' | grep -qx "${cls,,}"
}

close_wm_class() {
    local cls="$1"
    if [ -z "$cls" ]; then
        return 1
    fi
    local cls_lc="${cls,,}"
    if gnome_eval_raw "global.get_window_actors().filter(w => w.get_meta_window().get_wm_class().toLowerCase() === '${cls_lc}').forEach(w => w.get_meta_window().delete(global.get_current_time()));" >/dev/null; then
        return 0
    fi
    if command -v wmctrl >/dev/null 2>&1; then
        ensure_display_env
        local ids
        ids="$(wmctrl -x -l 2>/dev/null | awk -v cls="$cls_lc" '{
            class=tolower($4);
            split(class, parts, ".");
            if (class==cls || parts[1]==cls || parts[2]==cls) {
                print $1
            }
        }')"
        if [ -n "$ids" ]; then
            while read -r id; do
                [ -z "$id" ] && continue
                wmctrl -i -c "$id" >/dev/null 2>&1 || true
            done <<< "$ids"
            return 0
        fi
    fi
    return 1
}

get_dpms_mode() {
    local mode
    mode="$(busctl --user get-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode \
        2>/dev/null | awk '{print $2}' || true)"
    if [ -z "$mode" ] || ! [[ "$mode" =~ ^[0-9]+$ ]]; then
        log "Warning: unable to read PowerSaveMode; assuming display on."
        echo 0
        return 0
    fi
    echo "$mode"
}

set_dpms_mode() {
    local mode="$1"
    log "Setting PowerSaveMode to $mode (0=on, 1=standby, 2=suspend, 3=off)"
    if ! busctl --user set-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i "$mode"; then
        log "Error: failed to set PowerSaveMode to $mode"
        return 1
    fi
    # Verify the mode was set correctly
    local actual
    actual="$(busctl --user get-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode 2>/dev/null | awk '{print $2}')"
    if [ "$actual" != "$mode" ]; then
        log "Warning: PowerSaveMode set to $mode but actual is $actual"
    fi
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
        if who | awk '{print $NF}' | grep -E '\\([^)]*\\)' | grep -v '(:0)' | grep -q .; then
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

load_tlp_profile_state() {
    if [ -f "$TLP_STATE_FILE" ]; then
        cat "$TLP_STATE_FILE"
    fi
}

save_tlp_profile_state() {
    local profile="$1"
    if [ -z "$profile" ]; then
        return 0
    fi
    mkdir -p "$STATE_DIR"
    printf "%s" "$profile" > "$TLP_STATE_FILE"
}

have_tlp() {
    command -v tlp >/dev/null 2>&1
}

run_tlp_profile() {
    local profile="$1"
    if [ -z "$profile" ]; then
        return 0
    fi
    if [ "${DPMS_TLP_USE_SUDO:-0}" -eq 1 ]; then
        if command -v sudo >/dev/null 2>&1; then
            if sudo -n tlp "$profile" >/dev/null 2>&1; then
                return 0
            fi
        fi
        log "sudo tlp $profile not permitted; skipping profile switch."
        return 1
    fi
    tlp "$profile"
}

set_tlp_profile() {
    local profile="$1"
    if [ -z "$profile" ] || ! have_tlp; then
        return 1
    fi

    local current
    current="$(load_tlp_profile_state || true)"
    if [ "$current" = "$profile" ]; then
        return 0
    fi

    if run_tlp_profile "$profile"; then
        log "TLP profile set: $profile"
        save_tlp_profile_state "$profile"
        return 0
    fi

    log "Failed to set TLP profile: $profile"
    return 1
}

apply_power_profile() {
    local tlp_profile="$1"
    local ppd_profile="$2"

    if [ -n "$tlp_profile" ] && have_tlp; then
        if set_tlp_profile "$tlp_profile"; then
            return 0
        fi
    fi

    set_power_profile "$ppd_profile"
    return 0
}

get_logind_session_path() {
    local session_id
    session_id="$(get_session_id)" || return 1
    echo "/org/freedesktop/login1/session/_${session_id}"
}

capture_brightness() {
    if [ "${DPMS_BRIGHTNESS_RESTORE:-0}" -ne 1 ]; then
        return 1
    fi

    local device=""
    local value=""
    local out=""

    if command -v brightnessctl >/dev/null 2>&1; then
        if [ -n "${DPMS_BRIGHTNESS_DEVICE:-}" ]; then
            out="$(brightnessctl -m -d "$DPMS_BRIGHTNESS_DEVICE" 2>/dev/null || true)"
        else
            out="$(brightnessctl -m 2>/dev/null | head -n 1 || true)"
        fi
        if [ -n "$out" ]; then
            IFS=',' read -r device _ value _ _ <<< "$out"
        fi
    fi

    if [ -z "$device" ]; then
        if [ -n "${DPMS_BRIGHTNESS_DEVICE:-}" ]; then
            device="$DPMS_BRIGHTNESS_DEVICE"
        else
            device="$(ls /sys/class/backlight 2>/dev/null | head -n 1 || true)"
        fi
        if [ -n "$device" ] && [ -r "/sys/class/backlight/$device/brightness" ]; then
            value="$(cat "/sys/class/backlight/$device/brightness" 2>/dev/null || true)"
        fi
    fi

    if [ -n "$device" ] && [[ "${value:-}" =~ ^[0-9]+$ ]]; then
        BRIGHTNESS_DEVICE="$device"
        BRIGHTNESS_VALUE="$value"
        return 0
    fi
    return 1
}

restore_brightness() {
    if [ "${DPMS_BRIGHTNESS_RESTORE:-0}" -ne 1 ]; then
        return 0
    fi
    if [ -z "${BRIGHTNESS_DEVICE:-}" ] || [ -z "${BRIGHTNESS_VALUE:-}" ]; then
        return 0
    fi

    local device="$BRIGHTNESS_DEVICE"
    local value="$BRIGHTNESS_VALUE"

    if command -v brightnessctl >/dev/null 2>&1; then
        if brightnessctl -d "$device" set "$value" >/dev/null 2>&1; then
            log "Restored brightness via brightnessctl: $device=$value"
            return 0
        fi
    fi

    if [ -w "/sys/class/backlight/$device/brightness" ]; then
        if printf "%s" "$value" > "/sys/class/backlight/$device/brightness" 2>/dev/null; then
            log "Restored brightness via sysfs: $device=$value"
            return 0
        fi
    fi

    if command -v busctl >/dev/null 2>&1; then
        local session_path
        session_path="$(get_logind_session_path || true)"
        if [ -n "$session_path" ]; then
            if busctl call org.freedesktop.login1 "$session_path" \
                org.freedesktop.login1.Session SetBrightness "ssu" "backlight" "$device" "$value" \
                >/dev/null 2>&1; then
                log "Restored brightness via logind: $device=$value"
                return 0
            fi
        fi
    fi

    log "Warning: failed to restore brightness for $device"
    return 1
}

save_state() {
    local reopen_list="$1"
    local profile_before="$2"

    mkdir -p "$STATE_DIR"
    {
        echo "REOPEN_APPS=\"$reopen_list\""
        echo "POWER_PROFILE_BEFORE=\"$profile_before\""
        if [ -n "${BRIGHTNESS_DEVICE:-}" ] && [ -n "${BRIGHTNESS_VALUE:-}" ]; then
            echo "BRIGHTNESS_DEVICE=\"$BRIGHTNESS_DEVICE\""
            echo "BRIGHTNESS_VALUE=\"$BRIGHTNESS_VALUE\""
        fi
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

match_candidates() {
    local match="$1"
    local base segment
    local -a segments=()
    local -A emitted=()

    printf "%s\n" "$match"
    emitted["$match"]=1

    if [[ "$match" == *"|"* ]] && ! [[ "$match" =~ [\(\)\[\]\{\}] ]]; then
        IFS='|' read -r -a segments <<< "$match"
        for segment in "${segments[@]}"; do
            if [[ "$segment" == *"/"* ]]; then
                base="$(basename "$segment")"
                if [ "$base" != "$segment" ] && [ -z "${emitted[$base]+x}" ]; then
                    printf "%s\n" "$base"
                    emitted["$base"]=1
                fi
            fi
        done
        return 0
    fi

    base="$(basename "$match")"
    if [ "$base" != "$match" ] && [ -z "${emitted[$base]+x}" ]; then
        printf "%s\n" "$base"
    fi
}

# Unified function for finding running processes matching a pattern
# Usage: find_running_match <match> [mode]
#   mode: "check" (default) - returns 0 if found, 1 if not
#         "list" - outputs "pid cmdline" for each match
find_running_match() {
    local match="$1"
    local mode="${2:-check}"
    local cand pid cmdline found=1
    local -A seen_pids=()

    while IFS= read -r cand; do
        [ -z "$cand" ] && continue
        while read -r pid; do
            [ -z "$pid" ] && continue
            # Skip if we already processed this PID
            if [ -n "${seen_pids[$pid]+x}" ]; then
                continue
            fi
            seen_pids[$pid]=1
            cmdline="$(ps -p "$pid" -o args= 2>/dev/null)" || continue
            # Exclude pgrep/grep, this script, and shell wrappers
            if echo "$cmdline" | grep -qE 'pgrep|grep|dpms-toggle|nohup|bash -c'; then
                continue
            fi
            if [ "$mode" = "list" ]; then
                if [ "${#cmdline}" -gt 120 ]; then
                    cmdline="${cmdline:0:120}..."
                fi
                echo "$pid $cmdline"
            fi
            found=0
        done < <(pgrep -f -i "$cand" 2>/dev/null)
    done < <(match_candidates "$match")

    return $found
}

is_running_match() {
    find_running_match "$1" "check"
}

list_running_match() {
    find_running_match "$1" "list"
}

wait_for_exit() {
    local match="$1"
    local timeout="$2"
    local elapsed=0
    while is_running_match "$match"; do
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 0
}

kill_match() {
    local match="$1"
    local stopped=0

    # Primary: use the full regex pattern (covers all pipe-separated alternatives)
    if pgrep -f -i "$match" >/dev/null 2>&1; then
        log "Sending TERM to match: $match"
        pkill -TERM -f -i "$match" || true
        stopped=1
    fi

    # Fallback: only try individual segment basenames if the full pattern missed
    if [ "$stopped" -eq 0 ]; then
        local cand
        while IFS= read -r cand; do
            [ -z "$cand" ] && continue
            [ "$cand" = "$match" ] && continue
            if pgrep -f -i "$cand" >/dev/null 2>&1; then
                log "Sending TERM to fallback match: $cand"
                pkill -TERM -f -i "$cand" || true
                stopped=1
            fi
        done < <(match_candidates "$match")
    fi

    if [ "$stopped" -eq 0 ]; then
        return 1
    fi

    if ! wait_for_exit "$match" "$DPMS_KILL_WAIT_SEC"; then
        log "Force killing match: $match"
        pkill -KILL -f -i "$match" || true
        local cand
        while IFS= read -r cand; do
            [ -z "$cand" ] && continue
            [ "$cand" = "$match" ] && continue
            pkill -KILL -f -i "$cand" >/dev/null 2>&1 || true
        done < <(match_candidates "$match")
        wait_for_exit "$match" 2 || true
    fi

    return 0
}

run_command() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        return 0
    fi
    ensure_display_env
    if [[ "$cmd" == gtk-launch* ]] && ! command -v gtk-launch >/dev/null 2>&1; then
        local target
        target="$(echo "$cmd" | awk '{print $2}')"
        if command -v gio >/dev/null 2>&1; then
            cmd="gio launch ${target}.desktop"
        fi
    fi
    local first
    first="$(echo "$cmd" | awk '{print $1}')"
    if [[ "$first" == /* ]] && [ ! -x "$first" ]; then
        log "Warning: command not executable: $first"
    fi
    log "Executing: $cmd"
    nohup bash -c "exec 9>&-; $cmd" >/dev/null 2>&1 &
}

is_app_running() {
    local match="$1"
    local wm_class="$2"
    if is_running_match "$match"; then
        return 0
    fi
    if [ -n "$wm_class" ] && wm_class_running "$wm_class"; then
        return 0
    fi
    return 1
}

wait_for_app_start() {
    local match="$1"
    local wm_class="$2"
    local timeout="$3"
    local elapsed=0
    while ! is_app_running "$match" "$wm_class"; do
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 0
}

maybe_log_other_gui() {
    local -a handled_classes=("$@")

    if ! have_gdbus; then
        if [ "$DPMS_KILL_OTHER_GUI" -eq 1 ]; then
            log "gdbus not available; skipping other GUI shutdown."
        fi
        return 0
    fi

    local classes
    classes="$(get_wm_classes || true)"
    if [ -z "$classes" ]; then
        if [ "$DPMS_KILL_OTHER_GUI" -eq 1 ]; then
            log "No WM classes available; skipping other GUI shutdown."
        fi
        return 0
    fi

    log "Running GUI classes:"
    printf "%s\n" "$classes" | while read -r cls; do
        [ -z "$cls" ] && continue
        log "  $cls"

        if [ "$DPMS_KILL_OTHER_GUI" -eq 0 ]; then
            continue
        fi

        # Skip classes already handled by per-app and kill-only loops
        local handled=0
        if [ "${#handled_classes[@]}" -gt 0 ]; then
            for hcls in "${handled_classes[@]}"; do
                if [ "${hcls,,}" = "${cls,,}" ]; then
                    handled=1
                    break
                fi
            done
        fi
        if [ "$handled" -eq 1 ]; then
            continue
        fi

        local keep=0
        if [ "${#DPMS_KEEP_PROCS[@]}" -gt 0 ]; then
            for keep_name in "${DPMS_KEEP_PROCS[@]}"; do
                if [ "${keep_name,,}" = "${cls,,}" ]; then
                    keep=1
                    break
                fi
            done
        fi
        if [ "${cls,,}" = "org.gnome.shell" ] || [ "${cls,,}" = "gnome-shell" ]; then
            keep=1
        fi
        if [ "$keep" -eq 1 ]; then
            continue
        fi

        log "Stopping GUI app (best-effort): $cls"
        close_wm_class "$cls" || true
        pkill -TERM -f -i "$cls" >/dev/null 2>&1 || true
    done
}

stop_single_app() {
    local name="$1"
    local match="$2"
    local wm_class="$3"
    local close_cmd="$4"
    local status_file="$5"

    if is_app_running "$match" "$wm_class"; then
        printf "%s\n" "$name" >> "$status_file"
        log "Stopping $name (match: $match, class: ${wm_class:-none})"
        while read -r line; do
            log "  $line"
        done < <(list_running_match "$match")
        if [ -n "$close_cmd" ]; then
            log "Requesting $name to quit: $close_cmd"
            run_command "$close_cmd"
            wait_for_exit "$match" "$DPMS_KILL_WAIT_SEC" || true
        fi
        if [ -n "$wm_class" ]; then
            if close_wm_class "$wm_class"; then
                wait_for_exit "$match" "$DPMS_KILL_WAIT_SEC" || true
            fi
        fi
        if is_app_running "$match" "$wm_class"; then
            if [ -n "$close_cmd" ] && [ "${DPMS_FORCE_KILL_ON_CLOSE:-1}" -eq 0 ]; then
                log "Skip force kill for $name (close command used)."
            elif ! kill_match "$match"; then
                log "No matching process found for $name after check."
            fi
        fi
        if is_app_running "$match" "$wm_class"; then
            log "Warning: $name still running after close/kill."
            while read -r line; do
                log "  $line"
            done < <(list_running_match "$match")
        else
            log "$name stopped."
        fi
    else
        log "Not running: $name (match: $match, class: ${wm_class:-none})"
    fi
}

stop_kill_only_app() {
    local match="$1"
    local wm_class="$2"

    if is_app_running "$match" "$wm_class"; then
        log "Stopping (no reopen): $match"
        if [ -n "$wm_class" ]; then
            close_wm_class "$wm_class" || true
        fi
        kill_match "$match" || true
        if is_app_running "$match" "$wm_class"; then
            log "Warning: still running: $match"
        else
            log "Stopped: $match"
        fi
    fi
}

dpms_off() {
    if ! is_display_on; then
        log "Display already off."
        return 0
    fi

    if capture_brightness; then
        log "Saved brightness: ${BRIGHTNESS_DEVICE}=${BRIGHTNESS_VALUE}"
    fi

    local i name match wm_class close_cmd
    local -a handled_classes=()
    local -a pids=()
    local status_file
    status_file="$(mktemp "$STATE_DIR/dpms-reopen.XXXXXX")"

    for i in "${!DPMS_REOPEN_NAMES[@]}"; do
        name="${DPMS_REOPEN_NAMES[$i]}"
        match="${DPMS_KILL_MATCHES[$i]}"
        wm_class=""
        if [ "${#DPMS_WM_CLASSES[@]}" -gt 0 ]; then
            wm_class="${DPMS_WM_CLASSES[$i]}"
        fi
        if [ -n "$wm_class" ]; then
            handled_classes+=("$wm_class")
        fi
        close_cmd=""
        if [ "${#DPMS_CLOSE_COMMANDS[@]}" -gt 0 ]; then
            close_cmd="${DPMS_CLOSE_COMMANDS[$i]}"
        fi
        stop_single_app "$name" "$match" "$wm_class" "$close_cmd" "$status_file" &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done

    local reopen_apps=()
    if [ -f "$status_file" ]; then
        while IFS= read -r name; do
            [ -n "$name" ] && reopen_apps+=("$name")
        done < "$status_file"
    fi
    rm -f "$status_file"

    if [ "${#DPMS_KILL_ONLY_MATCHES[@]}" -gt 0 ]; then
        pids=()
        local j extra_match extra_class
        for j in "${!DPMS_KILL_ONLY_MATCHES[@]}"; do
            extra_match="${DPMS_KILL_ONLY_MATCHES[$j]}"
            extra_class=""
            if [ "${#DPMS_KILL_ONLY_WM_CLASSES[@]}" -gt 0 ]; then
                extra_class="${DPMS_KILL_ONLY_WM_CLASSES[$j]}"
            fi
            if [ -n "$extra_class" ]; then
                handled_classes+=("$extra_class")
            fi
            stop_kill_only_app "$extra_match" "$extra_class" &
            pids+=($!)
        done
        for pid in "${pids[@]}"; do
            wait "$pid" || true
        done
    fi

    maybe_log_other_gui "${handled_classes[@]}"

    local profile_before
    profile_before="$(get_power_profile)"
    if [ -n "$profile_before" ]; then
        log "Power profile before: $profile_before"
    fi

    # Prepare reopen list before saving state
    if [ "${DPMS_ALWAYS_REOPEN:-0}" -eq 1 ]; then
        reopen_apps=()
        for name in "${DPMS_REOPEN_NAMES[@]}"; do
            reopen_apps+=("$name")
        done
        log "Always reopen enabled; forcing reopen list: ${reopen_apps[*]}"
    elif [ "${#reopen_apps[@]}" -gt 0 ]; then
        log "Apps to reopen: ${reopen_apps[*]}"
    else
        log "No apps to reopen."
    fi

    # Save state BEFORE attempting DPMS change to prevent data loss on failure
    save_state "${reopen_apps[*]}" "$profile_before"

    # Attempt DPMS change - don't exit on failure since state is already saved
    if ! set_dpms_mode 1; then
        log "Warning: Failed to set DPMS mode, but state saved for recovery."
    fi

    if [ "${DPMS_SKIP_POWER_PROFILE:-0}" -eq 1 ]; then
        log "Skipping power profile switch."
    else
        local tlp_target=""
        local ppd_target=""
        if has_ssh_session; then
            tlp_target="${DPMS_TLP_PROFILE_OFF_SSH:-}"
            ppd_target="${DPMS_POWER_PROFILE_OFF_SSH:-}"
            log "SSH session detected; using power profile: ${tlp_target:-$ppd_target}"
        else
            tlp_target="${DPMS_TLP_PROFILE_OFF:-}"
            ppd_target="${DPMS_POWER_PROFILE_OFF:-}"
            log "No SSH session; using power profile: ${tlp_target:-$ppd_target}"
        fi
        apply_power_profile "$tlp_target" "$ppd_target"
    fi

    log "Display off."

    if [ "$DPMS_SUSPEND_IF_NO_SSH" -eq 1 ] && ! has_ssh_session; then
        if command -v systemctl >/dev/null 2>&1; then
            log "Scheduling suspend in ${DPMS_SUSPEND_DELAY_SEC}s..."
            (
                exec 9>&-
                sleep "$DPMS_SUSPEND_DELAY_SEC"
                if ! is_display_on && ! has_ssh_session; then
                    systemctl suspend || true
                fi
            ) &
        else
            log "systemctl not found; cannot suspend."
        fi
    fi
}

start_single_app() {
    local name="$1"
    local idx="$2"

    local cmd="${DPMS_REOPEN_COMMANDS[$idx]}"
    local match="${DPMS_KILL_MATCHES[$idx]}"
    local run_match="$match"
    if [ "${#DPMS_RUNNING_MATCHES[@]}" -gt 0 ]; then
        run_match="${DPMS_RUNNING_MATCHES[$idx]}"
    fi
    local activate_cmd=""
    if [ "${#DPMS_REOPEN_ACTIVATE_COMMANDS[@]}" -gt 0 ]; then
        activate_cmd="${DPMS_REOPEN_ACTIVATE_COMMANDS[$idx]}"
    fi
    local wm_class=""
    if [ "${#DPMS_WM_CLASSES[@]}" -gt 0 ]; then
        wm_class="${DPMS_WM_CLASSES[$idx]}"
    fi

    if is_app_running "$run_match" "$wm_class"; then
        if [ -n "$activate_cmd" ]; then
            log "Already running; activating $name"
            run_command "$activate_cmd"
        else
            log "Skip start; already running: $name"
        fi
        return 0
    fi

    if is_running_match "$match"; then
        log "Cleaning leftover processes for $name before start."
        kill_match "$match" || true
    fi

    local attempt=1
    while [ "$attempt" -le "$DPMS_START_RETRIES" ]; do
        log "Starting $name (attempt $attempt)..."
        run_command "$cmd"
        if wait_for_app_start "$run_match" "$wm_class" "$DPMS_START_WAIT_SEC"; then
            log "$name started."
            return 0
        fi
        log "Warning: $name did not start yet."
        attempt=$((attempt + 1))
    done

    if ! is_app_running "$run_match" "$wm_class" && [ -x "$match" ] && [ "$cmd" != "$match" ]; then
        log "Fallback start using match path: $match"
        run_command "$match"
        wait_for_app_start "$run_match" "$wm_class" "$DPMS_START_WAIT_SEC" || true
    fi

    if ! is_app_running "$run_match" "$wm_class"; then
        log "Error: failed to start $name after retries."
        while read -r line; do
            log "  $line"
        done < <(list_running_match "$match")
    fi
}

dpms_on() {
    if is_display_on; then
        log "Display already on."
    else
        set_dpms_mode 0
    fi

    load_state

    if [ "${DPMS_SKIP_POWER_PROFILE:-0}" -eq 1 ]; then
        log "Skipping power profile restore."
    else
        local profile_before="${POWER_PROFILE_BEFORE:-}"
        local ppd_target="$DPMS_POWER_PROFILE_ON"
        if [ -n "$profile_before" ]; then
            ppd_target="$profile_before"
        fi
        apply_power_profile "${DPMS_TLP_PROFILE_ON:-}" "$ppd_target"
    fi

    restore_brightness || true

    if [ -z "${REOPEN_APPS:-}" ] && [ "${DPMS_ALWAYS_REOPEN:-0}" -eq 1 ]; then
        REOPEN_APPS="${DPMS_REOPEN_NAMES[*]}"
    fi

    if [ -n "${REOPEN_APPS:-}" ]; then
        log "Reopen list: $REOPEN_APPS"
        local reopen_list=()
        IFS=' ' read -r -a reopen_list <<< "$REOPEN_APPS"
        if [ "$DPMS_REOPEN_DELAY_SEC" -gt 0 ]; then
            sleep "$DPMS_REOPEN_DELAY_SEC"
        fi

        local i name idx
        local -a pids=()
        for name in "${reopen_list[@]}"; do
            idx=-1
            for i in "${!DPMS_REOPEN_NAMES[@]}"; do
                if [ "${DPMS_REOPEN_NAMES[$i]}" = "$name" ]; then
                    idx="$i"
                    break
                fi
            done
            if [ "$idx" -ge 0 ]; then
                start_single_app "$name" "$idx" &
                pids+=($!)
            else
                log "No command mapping found for $name"
            fi
        done
        for pid in "${pids[@]}"; do
            wait "$pid" || true
        done
    else
        log "No apps recorded for reopen."
    fi

    clear_state
    log "Display on."
}

usage() {
    cat <<EOF
Usage: dpms-toggle [--on|--off|--toggle]

--toggle   Toggle display power (default)
--off      Force display off
--on       Force display on and restore apps
EOF
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
