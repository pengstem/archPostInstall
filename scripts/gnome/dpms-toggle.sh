#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# shellcheck source=scripts/gnome/dpms-common.sh
. "$SCRIPT_DIR/dpms-common.sh"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
RUNTIME_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall"
LOCK_FILE="$RUNTIME_DIR/dpms.lock"
DISPLAY_OFF_MODE=1
DISPLAY_ON_MODE=0
CURRENT_UID="$(id -u)"
START_WAIT_SEC=15
START_RETRIES=3
KILL_WAIT_SEC=6

usage() {
  cat <<'EOF'
Usage: dpms-toggle [--on|--off|--toggle]

--toggle   Toggle display power (default)
--off      Turn the display off and stop configured apps
--on       Turn the display on and start configured apps
EOF
}

case "${1:-}" in
-h | --help | help)
  usage
  exit 0
  ;;
esac

setup_runtime_env
load_dpms_config "$CONFIG_FILE" required 1
require_cmd busctl
require_cmd flock
require_cmd pgrep
require_cmd pkill
acquire_lock "$LOCK_FILE"

is_match_running() {
  local match="$1"

  pgrep -u "$CURRENT_UID" -f -i -- "$match" >/dev/null 2>&1
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

start_command() {
  local command="$1"

  dpms_log "Executing: $command"
  # Do not let the child inherit fd 9, otherwise it keeps the DPMS lock open.
  nohup /bin/bash -lc "exec 9>&-; $command" >/dev/null 2>&1 &
}

stop_app() {
  local name="$1"
  local match="$2"

  if ! is_match_running "$match"; then
    return 0
  fi

  dpms_log "Stopping $name"
  pkill -u "$CURRENT_UID" -TERM -f -i -- "$match" >/dev/null 2>&1 || true
  if wait_for_exit "$match" "$KILL_WAIT_SEC"; then
    return 0
  fi

  dpms_log "Sending KILL to $name"
  pkill -u "$CURRENT_UID" -KILL -f -i -- "$match" >/dev/null 2>&1 || true
  if ! wait_for_exit "$match" 2; then
    dpms_log "Warning: $name is still running."
    return 1
  fi

  return 0
}

start_app() {
  local name="$1"
  local match="$2"
  local start_cmd="$3"
  local attempt=1

  if is_match_running "$match"; then
    return 0
  fi

  while [ "$attempt" -le "$START_RETRIES" ]; do
    dpms_log "Starting $name (attempt $attempt)"
    start_command "$start_cmd"
    if wait_for_start "$match" "$START_WAIT_SEC"; then
      return 0
    fi
    attempt=$((attempt + 1))
  done

  dpms_log "Error: failed to start $name."
  return 1
}

get_display_mode() {
  local mode

  if ! mode="$(busctl --user get-property org.gnome.Mutter.DisplayConfig \
    /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode)"; then
    dpms_log "Error: unable to read display power state."
    return 1
  fi
  mode="${mode##* }"

  if ! [[ "$mode" =~ ^[0-9]+$ ]]; then
    dpms_log "Error: invalid display power state: $mode"
    return 1
  fi

  printf "%s\n" "$mode"
}

set_display_mode() {
  local mode="$1"

  dpms_log "Setting PowerSaveMode to $mode"
  busctl --user set-property org.gnome.Mutter.DisplayConfig \
    /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i "$mode" \
    >/dev/null 2>&1
}

dpms_off() {
  local record app_name app_match app_action

  if ! set_display_mode "$DISPLAY_OFF_MODE"; then
    dpms_log "Error: failed to turn the display off."
    return 1
  fi

  for record in "${DPMS_APPS[@]}"; do
    IFS="$DPMS_RECORD_SEP" read -r app_name app_match _ app_action <<<"$record"
    case "$app_action" in
    restart | stop)
      stop_app "$app_name" "$app_match" || true
      ;;
    start)
      ;;
    esac
  done

  dpms_log "Display off."
}

dpms_on() {
  local record app_name app_match app_start app_action

  if ! set_display_mode "$DISPLAY_ON_MODE"; then
    dpms_log "Error: failed to turn the display on."
    return 1
  fi

  for record in "${DPMS_APPS[@]}"; do
    IFS="$DPMS_RECORD_SEP" read -r app_name app_match app_start app_action <<<"$record"
    case "$app_action" in
    restart | start)
      start_app "$app_name" "$app_match" "$app_start" || true
      ;;
    stop)
      ;;
    esac
  done

  dpms_log "Display on."
}

case "${1:-}" in
--off)
  dpms_off
  ;;
--on)
  dpms_on
  ;;
--toggle | "")
  if [ "$(get_display_mode)" -eq 0 ]; then
    dpms_off
  else
    dpms_on
  fi
  ;;
-h | --help | help)
  usage
  ;;
*)
  echo "Unknown option: $1" >&2
  usage
  exit 1
  ;;
esac
