#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_FILE="$CONFIG_HOME/archpostinstall/screensaver.conf"
ART_FILE="$CONFIG_HOME/archpostinstall/screensaver.txt"
IDLE_HELPER="$SCRIPT_DIR/screensaver-idle.py"
RUNTIME_BASE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
RUNTIME_DIR="$RUNTIME_BASE/archpostinstall"
RUNNER_PID_FILE="$RUNTIME_DIR/screensaver.pid"
START_LOCK_FILE="$RUNTIME_DIR/screensaver-start.lock"
TTFX_BIN=""

usage() {
    cat <<'EOF'
Usage: archpostinstall-screensaver [command]

Commands:
  toggle        Start or stop the screensaver (default)
  start         Open the screensaver now
  stop          Close the running screensaver
  status        Show runner and idle-service state
  upgrade       Upgrade the Rust renderer to the latest stable release
  install       Enable idle launch and register Super+F11 in GNOME
  uninstall     Disable idle launch and remove the GNOME shortcut
  idle-daemon   Run the GNOME idle monitor (used by systemd)
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: required command not found: $1" >&2
        return 1
    fi
}

resolve_ttfx() {
    local candidate

    if command -v ttfx >/dev/null 2>&1; then
        TTFX_BIN="$(command -v ttfx)"
        return 0
    fi

    for candidate in \
        "${XDG_BIN_HOME:+$XDG_BIN_HOME/ttfx}" \
        "$HOME/.local/bin/ttfx" \
        "$HOME/.cargo/bin/ttfx"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            TTFX_BIN="$(readlink -f "$candidate" 2>/dev/null || echo "$candidate")"
            return 0
        fi
    done

    echo "Error: required screensaver renderer not found: ttfx" >&2
    echo "Run ./scripts/install/install_ttfx.sh to install the pinned Rust renderer." >&2
    return 1
}

load_config() {
    if [ ! -r "$CONFIG_FILE" ]; then
        echo "Error: screensaver config not found: $CONFIG_FILE" >&2
        return 1
    fi
    if [ ! -r "$ART_FILE" ]; then
        echo "Error: screensaver art not found: $ART_FILE" >&2
        return 1
    fi

    SCREENSAVER_EFFECTS=()
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    if ! [[ "${SCREENSAVER_IDLE_SECONDS:-}" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: SCREENSAVER_IDLE_SECONDS must be a positive integer." >&2
        return 1
    fi
    if ! [[ "${SCREENSAVER_FONT_SIZE:-}" =~ ^[1-9][0-9]*([.][0-9]+)?$ ]]; then
        echo "Error: SCREENSAVER_FONT_SIZE must be a positive number." >&2
        return 1
    fi
    if ! [[ "${SCREENSAVER_FRAME_RATE:-}" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: SCREENSAVER_FRAME_RATE must be a positive integer." >&2
        return 1
    fi
    if ! [[ "${SCREENSAVER_INPUT_GRACE_SECONDS:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "Error: SCREENSAVER_INPUT_GRACE_SECONDS must be a non-negative number." >&2
        return 1
    fi
    if [ -z "${SCREENSAVER_FONT_FAMILY:-}" ] || [ -z "${SCREENSAVER_SHORTCUT:-}" ]; then
        echo "Error: font family and shortcut must not be empty." >&2
        return 1
    fi
    if [ "${#SCREENSAVER_EFFECTS[@]}" -eq 0 ]; then
        echo "Error: at least one screensaver effect is required." >&2
        return 1
    fi
}

read_runner_pid() {
    local pid

    [ -r "$RUNNER_PID_FILE" ] || return 1
    read -r pid <"$RUNNER_PID_FILE" || return 1
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
    printf '%s\n' "$pid"
}

runner_is_running() {
    local pid cmdline

    pid="$(read_runner_pid)" || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1
    cmdline="$(tr '\0' ' ' <"/proc/$pid/cmdline")"

    [[ "$cmdline" == *"screensaver.sh run"* || \
        "$cmdline" == *"archpostinstall-screensaver run"* ]]
}

stop_screensaver() {
    local pid attempt

    if ! runner_is_running; then
        rm -f "$RUNNER_PID_FILE"
        return 0
    fi

    pid="$(read_runner_pid)"
    kill -TERM "$pid" 2>/dev/null || true
    for ((attempt = 0; attempt < 30; attempt++)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$RUNNER_PID_FILE"
            return 0
        fi
        sleep 0.1
    done

    kill -KILL "$pid" 2>/dev/null || true
    rm -f "$RUNNER_PID_FILE"
}

start_screensaver() {
    local attempt
    local -a kitty_args

    load_config
    require_cmd flock
    require_cmd kitty
    require_cmd python
    resolve_ttfx
    mkdir -p "$RUNTIME_DIR"

    exec 9>"$START_LOCK_FILE"
    if ! flock -n 9; then
        return 0
    fi
    if runner_is_running; then
        return 0
    fi
    rm -f "$RUNNER_PID_FILE"

    kitty_args=(
        --detach
        --config NONE
        --class org.archpostinstall.screensaver
        --name org.archpostinstall.screensaver
        --title "NASTEM Screensaver"
        --start-as fullscreen
        --override "font_family=$SCREENSAVER_FONT_FAMILY"
        --override "font_size=$SCREENSAVER_FONT_SIZE"
        --override "background=#000000"
        --override "foreground=#c0caf5"
        --override "cursor=#000000"
        --override "window_padding_width=0"
        --override "hide_window_decorations=yes"
        --override "confirm_os_window_close=0"
        --override "enable_audio_bell=no"
        --override "tab_bar_style=hidden"
    )
    kitty "${kitty_args[@]}" "$SCRIPT_PATH" run

    for ((attempt = 0; attempt < 50; attempt++)); do
        if runner_is_running; then
            return 0
        fi
        sleep 0.1
    done

    echo "Error: the screensaver window did not start." >&2
    return 1
}

run_screensaver() {
    local activity_pid="" effect_pid="" saved_pid=""
    local -a effect_args

    load_config
    require_cmd python
    resolve_ttfx
    mkdir -p "$RUNTIME_DIR"

    if runner_is_running; then
        saved_pid="$(read_runner_pid)"
        if [ "$saved_pid" != "$$" ]; then
            return 0
        fi
    fi
    printf '%s\n' "$$" >"$RUNNER_PID_FILE"

    cleanup() {
        trap - EXIT INT TERM HUP QUIT
        if [ -n "$effect_pid" ]; then
            kill -TERM "$effect_pid" 2>/dev/null || true
            wait "$effect_pid" 2>/dev/null || true
        fi
        if [ -n "$activity_pid" ]; then
            kill -TERM "$activity_pid" 2>/dev/null || true
            wait "$activity_pid" 2>/dev/null || true
        fi
        printf '\033[0m\033[?25h\033[2J\033[H'
        if [ "$(read_runner_pid 2>/dev/null || true)" = "$$" ]; then
            rm -f "$RUNNER_PID_FILE"
        fi
    }
    trap cleanup EXIT
    trap 'exit 0' INT TERM HUP QUIT

    (
        sleep "$SCREENSAVER_INPUT_GRACE_SECONDS"
        exec python "$IDLE_HELPER" wait-active --pid "$$"
    ) >/dev/null 2>&1 &
    activity_pid=$!

    effect_args=(
        --input-file "$ART_FILE"
        --terminal-background-color 000000
        --frame-rate "$SCREENSAVER_FRAME_RATE"
        --canvas-width 0
        --canvas-height 0
        --anchor-canvas c
        --anchor-text c
        --reuse-canvas
        --no-eol
        --no-restore-cursor
        --random-effect
        --include-effects "${SCREENSAVER_EFFECTS[@]}"
    )

    printf '\033]11;rgb:00/00/00\007\033[2J\033[H\033[?25l'
    while true; do
        "$TTFX_BIN" "${effect_args[@]}" &
        effect_pid=$!
        while kill -0 "$effect_pid" 2>/dev/null; do
            if IFS= read -r -s -n 1 -t 0.1; then
                return 0
            fi
        done
        wait "$effect_pid" 2>/dev/null || true
        effect_pid=""
    done
}

run_idle_daemon() {
    load_config
    require_cmd python
    exec python "$IDLE_HELPER" daemon \
        --timeout "$SCREENSAVER_IDLE_SECONDS" \
        --launcher "$SCRIPT_PATH"
}

install_integration() {
    local shortcut_command="$HOME/.local/bin/archpostinstall-screensaver toggle"

    load_config
    require_cmd gsettings
    require_cmd python
    require_cmd systemctl

    python "$IDLE_HELPER" install-shortcut \
        --binding "$SCREENSAVER_SHORTCUT" \
        --command "$shortcut_command"
    systemctl --user daemon-reload
    systemctl --user enable --now archpostinstall-screensaver.service
}

uninstall_integration() {
    local shortcut_command="$HOME/.local/bin/archpostinstall-screensaver toggle"

    load_config
    stop_screensaver
    systemctl --user disable --now archpostinstall-screensaver.service 2>/dev/null || true
    python "$IDLE_HELPER" remove-shortcut --command "$shortcut_command"
}

show_status() {
    local renderer_version

    if load_config >/dev/null 2>&1 && resolve_ttfx >/dev/null 2>&1; then
        renderer_version="$("$TTFX_BIN" --version 2>/dev/null || echo unknown)"
        echo "renderer: $renderer_version ($TTFX_BIN)"
    else
        echo "renderer: unavailable"
    fi

    if runner_is_running; then
        echo "screensaver: running (PID $(read_runner_pid))"
    else
        echo "screensaver: stopped"
    fi

    if systemctl --user is-enabled archpostinstall-screensaver.service >/dev/null 2>&1; then
        echo "idle service: enabled"
    else
        echo "idle service: disabled"
    fi
    if systemctl --user is-active archpostinstall-screensaver.service >/dev/null 2>&1; then
        echo "idle monitor: active"
    else
        echo "idle monitor: inactive"
    fi
}

upgrade_renderer() {
    if [ ! -x "$SCRIPT_DIR/../install/install_ttfx.sh" ]; then
        echo "Error: ttfx installer not found next to this repository checkout." >&2
        return 1
    fi
    "$SCRIPT_DIR/../install/install_ttfx.sh" upgrade
}

case "${1:-toggle}" in
    toggle)
        if runner_is_running; then
            stop_screensaver
        else
            start_screensaver
        fi
        ;;
    start)
        start_screensaver
        ;;
    stop)
        stop_screensaver
        ;;
    status)
        show_status
        ;;
    upgrade)
        upgrade_renderer
        ;;
    install)
        install_integration
        ;;
    uninstall)
        uninstall_integration
        ;;
    idle-daemon)
        run_idle_daemon
        ;;
    run)
        run_screensaver
        ;;
    -h | --help | help)
        usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage >&2
        exit 1
        ;;
esac
