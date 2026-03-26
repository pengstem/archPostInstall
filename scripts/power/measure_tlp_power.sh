#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

. "$SCRIPT_DIR/../gnome/dpms-common.sh"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archpostinstall/dpms.conf"
POWER_SUPPLY="${POWER_SUPPLY:-BAT0}"
MEASURE_SECONDS="${MEASURE_SECONDS:-30}"
MEASURE_INTERVAL="${MEASURE_INTERVAL:-1}"
SETTLE_SECONDS="${SETTLE_SECONDS:-10}"

setup_runtime_env
load_dpms_config "$CONFIG_FILE" optional 0
dpms_init_log "measure-power"

power_path="/sys/class/power_supply/${POWER_SUPPLY}/power_now"
energy_path="/sys/class/power_supply/${POWER_SUPPLY}/energy_now"
current_path="/sys/class/power_supply/${POWER_SUPPLY}/current_now"
voltage_path="/sys/class/power_supply/${POWER_SUPPLY}/voltage_now"

status_path="/sys/class/power_supply/${POWER_SUPPLY}/status"
if [ -r "$status_path" ]; then
    status="$(cat "$status_path")"
    if [ "$status" != "Discharging" ]; then
        dpms_log "Battery status is $status; measurements may be skewed."
    fi
fi

if ! [[ "$MEASURE_SECONDS" =~ ^[0-9]+$ ]] || \
   ! [[ "$MEASURE_INTERVAL" =~ ^[0-9]+$ ]] || \
   [ "$MEASURE_INTERVAL" -le 0 ]; then
    dpms_log "Invalid MEASURE_SECONDS/MEASURE_INTERVAL values."
    exit 1
fi

have_tlp() {
    command -v tlp >/dev/null 2>&1
}

run_tlp_profile() {
    local profile="$1"

    if [ "${DPMS_TLP_USE_SUDO:-1}" -eq 1 ]; then
        if command -v sudo >/dev/null 2>&1 && sudo -n tlp "$profile" >/dev/null 2>&1; then
            return 0
        fi
        dpms_log "sudo tlp $profile not permitted; cannot switch profile."
        return 1
    fi

    tlp "$profile" >/dev/null 2>&1
}

set_profile() {
    local profile="$1"

    if [ -z "$profile" ] || ! have_tlp; then
        return 1
    fi

    dpms_log "Switching TLP profile: $profile"
    run_tlp_profile "$profile"
}

is_effectively_zero() {
    local value="$1"
    awk -v v="$value" 'BEGIN { exit (v < 0.001 && v > -0.001) ? 0 : 1 }'
}

measure_power_avg_power_now() {
    local samples sum i value avg

    if [ ! -r "$power_path" ]; then
        return 1
    fi

    samples=$((MEASURE_SECONDS / MEASURE_INTERVAL))
    sum=0
    for ((i=0; i<samples; i++)); do
        value="$(cat "$power_path")"
        if [[ "$value" =~ ^-?[0-9]+$ ]]; then
            sum=$((sum + value))
        fi
        sleep "$MEASURE_INTERVAL"
    done

    if [ "$samples" -le 0 ]; then
        return 1
    fi

    avg=$((sum / samples))
    awk -v v="$avg" 'BEGIN { printf "%.3f", v / 1000000 }'
}

measure_power_avg_energy_delta() {
    local start end delta

    if [ ! -r "$energy_path" ]; then
        return 1
    fi

    start="$(cat "$energy_path")"
    sleep "$MEASURE_SECONDS"
    end="$(cat "$energy_path")"

    if ! [[ "$start" =~ ^-?[0-9]+$ ]] || ! [[ "$end" =~ ^-?[0-9]+$ ]]; then
        return 1
    fi

    delta=$((start - end))
    if [ "$delta" -le 0 ]; then
        return 1
    fi

    awk -v d="$delta" -v s="$MEASURE_SECONDS" 'BEGIN { printf "%.3f", (d / 1000000) / (s / 3600) }'
}

measure_power_avg_current_voltage() {
    local samples sum i current voltage avg

    if [ ! -r "$current_path" ] || [ ! -r "$voltage_path" ]; then
        return 1
    fi

    samples=$((MEASURE_SECONDS / MEASURE_INTERVAL))
    sum=0
    for ((i=0; i<samples; i++)); do
        current="$(cat "$current_path")"
        voltage="$(cat "$voltage_path")"
        if [[ "$current" =~ ^-?[0-9]+$ ]] && [[ "$voltage" =~ ^-?[0-9]+$ ]]; then
            sum=$((sum + current * voltage))
        fi
        sleep "$MEASURE_INTERVAL"
    done

    if [ "$samples" -le 0 ]; then
        return 1
    fi

    avg=$((sum / samples))
    awk -v v="$avg" 'BEGIN { printf "%.3f", (v < 0 ? -v : v) / 1000000000000 }'
}

measure_power_avg_upower() {
    local device rate

    if ! command -v upower >/dev/null 2>&1; then
        return 1
    fi

    device="$(upower -e 2>/dev/null | awk -v bat="$POWER_SUPPLY" '$0 ~ "battery_"bat"$" {print; exit}')"
    if [ -z "$device" ]; then
        return 1
    fi

    rate="$(upower -i "$device" 2>/dev/null | awk -F: '/energy-rate/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}')"
    if [ -z "$rate" ]; then
        return 1
    fi

    printf "%.3f" "$(echo "$rate" | awk '{print $1}')"
}

measure_power_avg() {
    local avg

    avg="$(measure_power_avg_power_now || true)"
    if [ -n "$avg" ] && ! is_effectively_zero "$avg"; then
        printf "%s|power_now\n" "$avg"
        return 0
    fi

    avg="$(measure_power_avg_energy_delta || true)"
    if [ -n "$avg" ] && ! is_effectively_zero "$avg"; then
        printf "%s|energy_delta\n" "$avg"
        return 0
    fi

    avg="$(measure_power_avg_current_voltage || true)"
    if [ -n "$avg" ] && ! is_effectively_zero "$avg"; then
        printf "%s|current_voltage\n" "$avg"
        return 0
    fi

    avg="$(measure_power_avg_upower || true)"
    if [ -n "$avg" ] && ! is_effectively_zero "$avg"; then
        printf "%s|upower\n" "$avg"
        return 0
    fi

    return 1
}

measure_profile() {
    local label="$1"
    local profile="$2"
    local result avg source

    if ! set_profile "$profile"; then
        dpms_log "Failed to set profile $profile; skipping $label."
        return 1
    fi

    sleep "$SETTLE_SECONDS"
    result="$(measure_power_avg)" || {
        dpms_log "No usable power source found for $label."
        if [ "${status:-}" != "Discharging" ]; then
            dpms_log "Tip: unplug AC so the battery is Discharging, or set POWER_SUPPLY to the active battery."
        fi
        return 1
    }

    IFS='|' read -r avg source <<< "$result"
    if [ -z "$source" ]; then
        source="unknown"
    fi

    printf "%s: %s W (profile: %s, source: %s)\n" "$label" "$avg" "$profile" "$source"
}

if ! have_tlp; then
    dpms_log "tlp not found; cannot measure."
    exit 1
fi

measure_ok=0
if measure_profile "Display Off" "$DPMS_PROFILE_OFF"; then
    measure_ok=1
fi
if measure_profile "Display Off (SSH)" "$DPMS_PROFILE_OFF_SSH"; then
    measure_ok=1
fi

if [ -n "${DPMS_PROFILE_ON:-}" ]; then
    set_profile "$DPMS_PROFILE_ON" || true
fi

if [ "$measure_ok" -eq 0 ]; then
    exit 1
fi
