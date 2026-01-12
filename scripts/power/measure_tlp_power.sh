#!/bin/bash

set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
POWER_SUPPLY="${POWER_SUPPLY:-BAT0}"
MEASURE_SECONDS="${MEASURE_SECONDS:-30}"
MEASURE_INTERVAL="${MEASURE_INTERVAL:-1}"
SETTLE_SECONDS="${SETTLE_SECONDS:-10}"

DPMS_TLP_PROFILE_ON="balanced"
DPMS_TLP_PROFILE_OFF="power-saver"
DPMS_TLP_PROFILE_OFF_SSH="performance"
DPMS_TLP_USE_SUDO=1

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "%s [measure-power] %s\n" "$ts" "$*" >&2
}

power_path="/sys/class/power_supply/${POWER_SUPPLY}/power_now"
if [ ! -r "$power_path" ]; then
    log "Missing power_now at $power_path"
    exit 1
fi

status_path="/sys/class/power_supply/${POWER_SUPPLY}/status"
if [ -r "$status_path" ]; then
    status="$(cat "$status_path")"
    if [ "$status" != "Discharging" ]; then
        log "Battery status is $status; measurements may be skewed."
    fi
fi

if ! [[ "$MEASURE_SECONDS" =~ ^[0-9]+$ ]] || \
   ! [[ "$MEASURE_INTERVAL" =~ ^[0-9]+$ ]] || \
   [ "$MEASURE_INTERVAL" -le 0 ]; then
    log "Invalid MEASURE_SECONDS/MEASURE_INTERVAL values."
    exit 1
fi

have_tlp() {
    command -v tlp >/dev/null 2>&1
}

run_tlp_profile() {
    local profile="$1"
    if [ "${DPMS_TLP_USE_SUDO:-0}" -eq 1 ]; then
        if command -v sudo >/dev/null 2>&1; then
            if sudo -n tlp "$profile" >/dev/null 2>&1; then
                return 0
            fi
        fi
        log "sudo tlp $profile not permitted; cannot switch profile."
        return 1
    fi
    tlp "$profile"
}

set_profile() {
    local profile="$1"
    if [ -z "$profile" ] || ! have_tlp; then
        return 1
    fi
    log "Switching TLP profile: $profile"
    run_tlp_profile "$profile"
}

measure_power_avg() {
    local samples=$((MEASURE_SECONDS / MEASURE_INTERVAL))
    local sum=0
    local i value avg

    for ((i=0; i<samples; i++)); do
        value="$(cat "$power_path")"
        if [[ "$value" =~ ^-?[0-9]+$ ]]; then
            sum=$((sum + value))
        fi
        sleep "$MEASURE_INTERVAL"
    done

    if [ "$samples" -le 0 ]; then
        log "Invalid sampling configuration."
        return 1
    fi

    avg=$((sum / samples))
    awk -v v="$avg" 'BEGIN { printf "%.3f", v / 1000000 }'
}

measure_profile() {
    local label="$1"
    local profile="$2"
    local avg
    if ! set_profile "$profile"; then
        log "Failed to set profile $profile; skipping $label."
        return 1
    fi
    sleep "$SETTLE_SECONDS"
    avg="$(measure_power_avg)"
    printf "%s: %s W (profile: %s)\n" "$label" "$avg" "$profile"
}

if ! have_tlp; then
    log "tlp not found; cannot measure."
    exit 1
fi

measure_profile "Power-saver" "$DPMS_TLP_PROFILE_OFF"
measure_profile "Performance" "$DPMS_TLP_PROFILE_OFF_SSH"

if [ -n "${DPMS_TLP_PROFILE_ON:-}" ]; then
    set_profile "$DPMS_TLP_PROFILE_ON" || true
fi
