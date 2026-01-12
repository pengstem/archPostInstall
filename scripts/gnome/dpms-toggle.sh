#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall"
STATE_FILE="$STATE_DIR/dpms.state"
TLP_STATE_FILE="$STATE_DIR/tlp.profile"
LOCK_FILE="$STATE_DIR/dpms.lock"
LOCK_DIR="$STATE_DIR/dpms.lock.d"

DPMS_REOPEN_NAMES=("firefox" "wechat" "qq")
DPMS_KILL_MATCHES=("firefox" "WeChat.AppImage|/tmp/.mount_WeChat|WeChatAppEx|/usr/bin/wechat" "QQ.AppImage|/tmp/.mount_QQ|/usr/bin/qq|/qq")
DPMS_WM_CLASSES=("firefox" "wechat" "qq")
DPMS_REOPEN_COMMANDS=("firefox" "/home/nastem/Applications/WeChat.AppImage" "/home/nastem/Applications/QQ.AppImage")
DPMS_KILL_ONLY_MATCHES=("steam")
DPMS_KILL_ONLY_WM_CLASSES=("steam")
DPMS_KEEP_PROCS=("kitty" "sparkle" "gnome-shell" "org.gnome.Shell")
DPMS_POWER_PROFILE_ON="balanced"
DPMS_POWER_PROFILE_OFF="power-saver"
DPMS_POWER_PROFILE_OFF_SSH="power-saver"
DPMS_TLP_PROFILE_ON="balanced"
DPMS_TLP_PROFILE_OFF="power-saver"
DPMS_TLP_PROFILE_OFF_SSH="performance"
DPMS_TLP_USE_SUDO=1
DPMS_IDLE_MINUTES=15
DPMS_SKIP_WHEN_PLAYING=1
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

IDLE_DEBUG_LINES=()
IDLE_ERROR=""

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
if [ "${#DPMS_WM_CLASSES[@]}" -gt 0 ] && \
   [ "${#DPMS_WM_CLASSES[@]}" -ne "${#DPMS_REOPEN_NAMES[@]}" ]; then
    echo "Error: DPMS_WM_CLASSES length must match DPMS_REOPEN_NAMES." >&2
    exit 1
fi
if [ "${#DPMS_KILL_ONLY_WM_CLASSES[@]}" -gt 0 ] && \
   [ "${#DPMS_KILL_ONLY_WM_CLASSES[@]}" -ne "${#DPMS_KILL_ONLY_MATCHES[@]}" ]; then
    echo "Error: DPMS_KILL_ONLY_WM_CLASSES length must match DPMS_KILL_ONLY_MATCHES." >&2
    exit 1
fi

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

reset_idle_debug() {
    IDLE_DEBUG_LINES=()
    IDLE_ERROR=""
}

append_idle_debug() {
    IDLE_DEBUG_LINES+=("$1")
}

emit_idle_debug() {
    local line
    for line in "${IDLE_DEBUG_LINES[@]}"; do
        log "$line"
    done
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
            log "Another dpms-toggle instance is running; skipping."
            exit 0
        fi
        return 0
    fi

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
    if ! have_gdbus; then
        return 1
    fi
    output="$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval "$js" 2>/dev/null)" || return 1
    if ! echo "$output" | grep -q "^(true,"; then
        log "GNOME Shell Eval unavailable: $output"
        return 1
    fi
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
    gnome_eval_raw "global.get_window_actors().filter(w => w.get_meta_window().get_wm_class().toLowerCase() === '${cls_lc}').forEach(w => w.get_meta_window().delete(global.get_current_time()));" >/dev/null
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
    if ! busctl --user set-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i "$1"; then
        log "Error: failed to set PowerSaveMode to $1"
        return 1
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
        if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
            sudo tlp "$profile"
            return $?
        fi
        log "sudo not available for tlp; skipping profile switch."
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

match_candidates() {
    local match="$1"
    local base
    local segment
    local -a segments=()
    base="$(basename "$match")"
    printf "%s\n" "$match"

    if [[ "$match" == *"|"* ]] && ! [[ "$match" =~ [\(\)\[\]\{\}] ]]; then
        IFS='|' read -r -a segments <<< "$match"
        for segment in "${segments[@]}"; do
            if [[ "$segment" == *"/"* ]]; then
                base="$(basename "$segment")"
                if [ "$base" != "$segment" ]; then
                    printf "%s\n" "$base"
                fi
            fi
        done
        return 0
    fi

    if [ "$base" != "$match" ]; then
        printf "%s\n" "$base"
    fi
}

is_running_match() {
    local match="$1"
    local cand
    while IFS= read -r cand; do
        if pgrep -f -i "$cand" >/dev/null 2>&1; then
            return 0
        fi
    done < <(match_candidates "$match")
    return 1
}

list_running_match() {
    local match="$1"
    local cand
    while IFS= read -r cand; do
        pgrep -af -i "$cand" 2>/dev/null || true
    done < <(match_candidates "$match")
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
    local cand
    local stopped=0

    while IFS= read -r cand; do
        if pgrep -f -i "$cand" >/dev/null 2>&1; then
            log "Sending TERM to match: $cand"
            pkill -TERM -f -i "$cand" || true
            stopped=1
        fi
    done < <(match_candidates "$match")

    if [ "$stopped" -eq 0 ]; then
        return 1
    fi

    if ! wait_for_exit "$match" "$DPMS_KILL_WAIT_SEC"; then
        log "Force killing match: $match"
        while IFS= read -r cand; do
            pkill -KILL -f -i "$cand" || true
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
    nohup bash -c "$cmd" >/dev/null 2>&1 &
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

        local keep=0
        for keep_name in "${DPMS_KEEP_PROCS[@]}"; do
            if [ "${keep_name,,}" = "${cls,,}" ]; then
                keep=1
                break
            fi
        done
        if [ "${cls,,}" = "org.gnome.shell" ] || [ "${cls,,}" = "gnome-shell" ]; then
            keep=1
        fi
        if [ "$keep" -eq 1 ]; then
            continue
        fi

        log "Stopping GUI app (best-effort): $cls"
        close_wm_class "$cls" || true
        pkill -TERM -x "$cls" >/dev/null 2>&1 || true
        pkill -TERM -f -i "$cls" >/dev/null 2>&1 || true
    done
}

dpms_off() {
    if ! is_display_on; then
        log "Display already off."
        return 0
    fi

    local i name match wm_class
    local reopen_apps=()

    for i in "${!DPMS_REOPEN_NAMES[@]}"; do
        name="${DPMS_REOPEN_NAMES[$i]}"
        match="${DPMS_KILL_MATCHES[$i]}"
        wm_class=""
        if [ "${#DPMS_WM_CLASSES[@]}" -gt 0 ]; then
            wm_class="${DPMS_WM_CLASSES[$i]}"
        fi
        if is_app_running "$match" "$wm_class"; then
            reopen_apps+=("$name")
            log "Stopping $name (match: $match, class: ${wm_class:-none})"
            while read -r line; do
                log "  $line"
            done < <(list_running_match "$match")
            if [ -n "$wm_class" ]; then
                close_wm_class "$wm_class" || true
            fi
            if ! kill_match "$match"; then
                log "No matching process found for $name after check."
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
    done

    if [ "${#DPMS_KILL_ONLY_MATCHES[@]}" -gt 0 ]; then
        local j extra_match extra_class
        for j in "${!DPMS_KILL_ONLY_MATCHES[@]}"; do
            extra_match="${DPMS_KILL_ONLY_MATCHES[$j]}"
            extra_class=""
            if [ "${#DPMS_KILL_ONLY_WM_CLASSES[@]}" -gt 0 ]; then
                extra_class="${DPMS_KILL_ONLY_WM_CLASSES[$j]}"
            fi
            if is_app_running "$extra_match" "$extra_class"; then
                log "Stopping (no reopen): $extra_match"
                if [ -n "$extra_class" ]; then
                    close_wm_class "$extra_class" || true
                fi
                kill_match "$extra_match" || true
                if is_app_running "$extra_match" "$extra_class"; then
                    log "Warning: still running: $extra_match"
                else
                    log "Stopped: $extra_match"
                fi
            fi
        done
    fi

    maybe_log_other_gui

    local profile_before
    profile_before="$(get_power_profile)"
    if [ -n "$profile_before" ]; then
        log "Power profile before: $profile_before"
    fi

    set_dpms_mode 1

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

    if [ "${#reopen_apps[@]}" -gt 0 ]; then
        log "Apps to reopen: ${reopen_apps[*]}"
    else
        log "No apps to reopen."
    fi
    save_state "${reopen_apps[*]}" "$profile_before"
    log "Display off."

    if [ "$DPMS_SUSPEND_IF_NO_SSH" -eq 1 ] && ! has_ssh_session; then
        if command -v systemctl >/dev/null 2>&1; then
            log "Scheduling suspend in ${DPMS_SUSPEND_DELAY_SEC}s..."
            (
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

dpms_on() {
    if is_display_on; then
        log "Display already on."
    else
        set_dpms_mode 0
    fi

    load_state

    local profile_before="${POWER_PROFILE_BEFORE:-}"
    local ppd_target="$DPMS_POWER_PROFILE_ON"
    if [ -n "$profile_before" ]; then
        ppd_target="$profile_before"
    fi
    apply_power_profile "${DPMS_TLP_PROFILE_ON:-}" "$ppd_target"

    if [ -n "${REOPEN_APPS:-}" ]; then
        log "Reopen list: $REOPEN_APPS"
        local reopen_list=()
        IFS=' ' read -r -a reopen_list <<< "$REOPEN_APPS"
        if [ "$DPMS_REOPEN_DELAY_SEC" -gt 0 ]; then
            sleep "$DPMS_REOPEN_DELAY_SEC"
        fi

        local i name cmd idx match wm_class attempt
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
                match="${DPMS_KILL_MATCHES[$idx]}"
                wm_class=""
                if [ "${#DPMS_WM_CLASSES[@]}" -gt 0 ]; then
                    wm_class="${DPMS_WM_CLASSES[$idx]}"
                fi
                if is_app_running "$match" "$wm_class"; then
                    log "Skip start; already running: $name"
                    continue
                fi
                attempt=1
                while [ "$attempt" -le "$DPMS_START_RETRIES" ]; do
                    log "Starting $name (attempt $attempt)..."
                    run_command "$cmd"
                    if wait_for_app_start "$match" "$wm_class" "$DPMS_START_WAIT_SEC"; then
                        log "$name started."
                        break
                    fi
                    log "Warning: $name did not start yet."
                    attempt=$((attempt + 1))
                done
                if ! is_app_running "$match" "$wm_class" && [ -x "$match" ] && [ "$cmd" != "$match" ]; then
                    log "Fallback start using match path: $match"
                    run_command "$match"
                    wait_for_app_start "$match" "$wm_class" "$DPMS_START_WAIT_SEC" || true
                fi
                if ! is_app_running "$match" "$wm_class"; then
                    log "Error: failed to start $name after retries."
                    while read -r line; do
                        log "  $line"
                    done < <(list_running_match "$match")
                fi
            else
                log "No command mapping found for $name"
            fi
        done
    else
        log "No apps recorded for reopen."
    fi

    clear_state
    log "Display on."
}

sync_off_power_profile() {
    local tlp_target=""
    local ppd_target=""
    if has_ssh_session; then
        tlp_target="${DPMS_TLP_PROFILE_OFF_SSH:-}"
        ppd_target="${DPMS_POWER_PROFILE_OFF_SSH:-}"
        log "SSH active while display off; using power profile: ${tlp_target:-$ppd_target}"
    else
        tlp_target="${DPMS_TLP_PROFILE_OFF:-}"
        ppd_target="${DPMS_POWER_PROFILE_OFF:-}"
        log "No SSH while display off; using power profile: ${tlp_target:-$ppd_target}"
    fi
    apply_power_profile "$tlp_target" "$ppd_target"
}

dpms_restore() {
    if [ ! -f "$STATE_FILE" ]; then
        log "No state file; nothing to restore."
        return 0
    fi
    if is_display_on; then
        dpms_on
    else
        sync_off_power_profile
        log "Display still off; restore deferred."
    fi
}

get_logind_idle_seconds() {
    if ! command -v loginctl >/dev/null 2>&1; then
        return 1
    fi

    local session_id raw hint since uptime_usec
    session_id="${XDG_SESSION_ID:-}"

    if [ -n "$session_id" ]; then
        raw="$(loginctl show-session "$session_id" -p IdleHint -p IdleSinceHintMonotonic 2>/dev/null)" || return 1
    else
        raw="$(loginctl show-user "$USER" -p IdleHint -p IdleSinceHintMonotonic 2>/dev/null)" || return 1
    fi

    hint="$(echo "$raw" | awk -F= '/IdleHint=/{print $2}')"
    since="$(echo "$raw" | awk -F= '/IdleSinceHintMonotonic=/{print $2}')"
    if [ -z "$hint" ]; then
        return 1
    fi

    append_idle_debug "IdleHint: $hint (IdleSinceHintMonotonic: ${since:-n/a})"

    if [ "$hint" = "no" ]; then
        echo 0
        return 0
    fi
    if [ "$hint" != "yes" ]; then
        return 1
    fi

    if ! [[ "$since" =~ ^[0-9]+$ ]] || [ "$since" -le 0 ]; then
        return 1
    fi
    if [ ! -r /proc/uptime ]; then
        return 1
    fi
    uptime_usec="$(awk '{printf "%d", $1*1000000}' /proc/uptime 2>/dev/null || true)"
    if ! [[ "$uptime_usec" =~ ^[0-9]+$ ]] || [ "$uptime_usec" -lt "$since" ]; then
        return 1
    fi

    echo $(((uptime_usec - since) / 1000000))
}

get_gnome_idle_seconds() {
    if ! command -v gdbus >/dev/null 2>&1; then
        return 1
    fi

    local raw
    raw="$(gdbus call --session --dest org.gnome.Mutter.IdleMonitor \
        --object-path /org/gnome/Mutter/IdleMonitor/Core \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null)" || return 1

    local ms
    ms="$(echo "$raw" | sed -E 's/.*uint64[[:space:]]+([0-9]+).*/\\1/')"
    if ! [[ "$ms" =~ ^[0-9]+$ ]]; then
        ms="$(echo "$raw" | sed -E 's/[^0-9]*([0-9]+).*/\\1/')"
    fi
    if ! [[ "$ms" =~ ^[0-9]+$ ]]; then
        IDLE_ERROR="Failed to parse idle time from: $raw"
        return 1
    fi

    append_idle_debug "Idle raw: $raw"

    echo $((ms / 1000))
}

get_idle_seconds() {
    local gnome_idle logind_idle gnome_error
    local -a gnome_debug=()

    reset_idle_debug
    gnome_idle="$(get_gnome_idle_seconds 2>/dev/null || true)"
    if [ -n "$gnome_idle" ]; then
        echo "$gnome_idle"
        return 0
    fi

    gnome_error="$IDLE_ERROR"
    gnome_debug=("${IDLE_DEBUG_LINES[@]}")

    reset_idle_debug
    logind_idle="$(get_logind_idle_seconds 2>/dev/null || true)"
    if [ -n "$logind_idle" ]; then
        echo "$logind_idle"
        return 0
    fi

    if [ -n "$gnome_error" ]; then
        IDLE_ERROR="$gnome_error"
        IDLE_DEBUG_LINES=("${gnome_debug[@]}")
    fi
    return 1
}

is_media_playing() {
    if ! command -v playerctl >/dev/null 2>&1; then
        return 1
    fi

    local statuses
    statuses="$(playerctl -a status 2>/dev/null || true)"
    if echo "$statuses" | grep -qi '^Playing$'; then
        return 0
    fi
    return 1
}

dpms_idle() {
    if ! [[ "${DPMS_IDLE_MINUTES:-}" =~ ^[0-9]+$ ]] || [ "$DPMS_IDLE_MINUTES" -le 0 ]; then
        log "Idle timeout disabled; skipping."
        return 0
    fi

    if ! is_display_on; then
        if [ "${DPMS_VERBOSE:-1}" -ge 2 ]; then
            log "Display already off; skipping idle check."
        fi
        return 0
    fi

    local idle_seconds
    idle_seconds="$(get_idle_seconds)" || {
        if [ -n "${IDLE_ERROR:-}" ]; then
            log "$IDLE_ERROR"
        fi
        if [ "${DPMS_VERBOSE:-1}" -ge 2 ]; then
            emit_idle_debug
        fi
        log "Idle monitor unavailable; skipping."
        return 0
    }

    local threshold=$((DPMS_IDLE_MINUTES * 60))
    if [ "${DPMS_VERBOSE:-1}" -ge 2 ]; then
        emit_idle_debug
        log "Idle: ${idle_seconds}s (threshold: ${threshold}s)"
    fi
    if [ "$idle_seconds" -ge "$threshold" ]; then
        if [ "${DPMS_SKIP_WHEN_PLAYING:-0}" -eq 1 ] && is_media_playing; then
            log "Media is playing; skipping display off."
            return 0
        fi
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
