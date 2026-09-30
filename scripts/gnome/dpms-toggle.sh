#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
DISPLAY_HELPER="$SCRIPT_DIR/dpms-display.py"
HOLD_UNIT="archpostinstall-dpms-hold"
STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/archpostinstall-dpms.state"
START_WAIT_SEC=15
START_RETRIES=3
KILL_WAIT_SEC=6

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

usage() {
    cat <<'EOF'
Usage: dpms-toggle [--on|--off|--toggle]

--toggle   Toggle display power (default)
--off      Turn the display off and stop configured apps
--on       Turn the display on and start configured apps
EOF
}

dpms_log() {
    printf "[dpms] %s\n" "$*" >&2
}

die() {
    echo "Error: $*" >&2
    exit 1
}

# Config DSL, see dpms.conf.
APP_NAME=()
APP_MATCH=()
APP_START=()
APP_ACTION=()
APP_SIGNAL=()

dpms_app() {
    local name="" match="" start="" action="restart" signal="TERM"

    while [ "$#" -ge 2 ]; do
        case "$1" in
            --name) name="$2" ;;
            --match) match="$2" ;;
            --start) start="$2" ;;
            --action) action="$2" ;;
            --signal) signal="$2" ;;
            *) die "unknown dpms_app option $1" ;;
        esac
        shift 2
    done
    [ "$#" -eq 0 ] || die "missing value for dpms_app option $1"
    [ -n "$name" ] && [ -n "$match" ] || die "dpms_app requires --name and --match."
    case "$action" in
        restart | start) [ -n "$start" ] || die "$action action requires --start for $name." ;;
        stop) ;;
        *) die "unsupported app action '$action' for $name." ;;
    esac

    APP_NAME+=("$name")
    APP_MATCH+=("$match")
    APP_START+=("$start")
    APP_ACTION+=("$action")
    APP_SIGNAL+=("$signal")
}

app_running() {
    pgrep -u "$UID" -f -i -- "$1" >/dev/null 2>&1
}

app_gone() {
    ! app_running "$1"
}

# wait_until SECONDS COMMAND...: poll COMMAND every 0.2 s.
wait_until() {
    local tries=$(($1 * 5))

    shift
    until "$@"; do
        ((tries-- > 0)) || return 1
        sleep 0.2
    done
}

stop_app() {
    local name="${APP_NAME[$1]}" match="${APP_MATCH[$1]}"

    pkill -u "$UID" -"${APP_SIGNAL[$1]}" -f -i -- "$match" >/dev/null 2>&1 || return 0
    dpms_log "Stopping $name"
    wait_until "$KILL_WAIT_SEC" app_gone "$match" && return 0

    dpms_log "Sending KILL to $name"
    pkill -u "$UID" -KILL -f -i -- "$match" >/dev/null 2>&1 || true
    wait_until 2 app_gone "$match" || dpms_log "Warning: $name is still running."
}

start_app() {
    local name="${APP_NAME[$1]}" match="${APP_MATCH[$1]}" command="${APP_START[$1]}" attempt

    app_running "$match" && return 0
    for ((attempt = 1; attempt <= START_RETRIES; attempt++)); do
        dpms_log "Starting $name (attempt $attempt)"
        # Do not let the app inherit fd 8, otherwise it keeps the app lock open.
        nohup /bin/bash -lc "$command" 8>&- >/dev/null 2>&1 &
        wait_until "$START_WAIT_SEC" app_running "$match" && return 0
    done
    dpms_log "Error: failed to start $name."
}

# Apps are handled concurrently; each one still escalates or retries alone.
for_each_app() {
    local skip_action="$1" handler="$2" i

    for i in "${!APP_NAME[@]}"; do
        [ "${APP_ACTION[i]}" = "$skip_action" ] && continue
        "$handler" "$i" &
    done
    wait
}

release_hold() {
    systemctl --user stop "$HOLD_UNIT" >/dev/null 2>&1 || true
}

display_off() {
    release_hold
    # Returns once the display is off (READY=1); see dpms-display.py.
    systemd-run --user --quiet --collect --unit="$HOLD_UNIT" \
        -p Type=notify -p TimeoutStartSec=5 -p SyslogIdentifier=dpms-hold \
        /usr/bin/python3 "$DISPLAY_HELPER" hold || return 1

    if ! "$SCRIPT_DIR/screensaver.sh" stop; then
        dpms_log "Warning: failed to stop the active screensaver."
    fi
}

display_on() {
    release_hold
    /usr/bin/python3 "$DISPLAY_HELPER" on
}

apps_off() {
    for_each_app start stop_app
}

apps_on() {
    for_each_app stop start_app
}

display_is_on() {
    local mode

    mode="$(busctl --user get-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode)"
    [ "${mode##* }" = 0 ]
}

case "${1:---toggle}" in
    --on) action=on ;;
    --off) action=off ;;
    --toggle) action=toggle ;;
    -h | --help | help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
esac

# shellcheck source=configs/archpostinstall/dpms.conf
. "$CONFIG_FILE"

# The display switch and the app phase take separate locks, so an app that
# is slow to exit (QQ ignores SIGTERM) never delays the next key press. Both
# queue instead of skipping. Queued app phases act on the latest request in
# STATE_FILE, so rapid toggles converge on the final state.
exec 9>"$XDG_RUNTIME_DIR/archpostinstall-dpms.lock"
flock -w 10 9 || die "timed out waiting for another DPMS instance."
if [ "$action" = toggle ]; then
    if display_is_on; then action=off; else action=on; fi
fi
"display_$action" || die "failed to turn the display $action."
echo "$action" >"$STATE_FILE"
dpms_log "Display $action."
exec 9>&-

exec 8>"$XDG_RUNTIME_DIR/archpostinstall-dpms-apps.lock"
flock 8
action="$(<"$STATE_FILE")"
"apps_$action"
