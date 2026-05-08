#!/usr/bin/env bash
# Battery low warning script.
# Sends a warning notification when battery is below WARN_THRESHOLD (20%)
# and a critical notification when below CRIT_THRESHOLD (10%).
# Notifications are delivered via the system notification daemon (e.g., dunst)
# through `notify-send`.

set -euo pipefail

WARN_THRESHOLD="${WARN_THRESHOLD:-20}"
CRIT_THRESHOLD="${CRIT_THRESHOLD:-10}"
BATTERY_PATH="${BATTERY_PATH:-/sys/class/power_supply/BAT0}"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/battery-warning"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/last-level"

if [[ ! -d "$BATTERY_PATH" ]]; then
    for bat in /sys/class/power_supply/BAT*; do
        if [[ -d "$bat" ]]; then
            BATTERY_PATH="$bat"
            break
        fi
    done
fi

if [[ ! -r "$BATTERY_PATH/capacity" ]]; then
    echo "No battery found at $BATTERY_PATH" >&2
    exit 0
fi

capacity=$(cat "$BATTERY_PATH/capacity")
status=$(cat "$BATTERY_PATH/status" 2>/dev/null || echo "Unknown")

last_level="none"
[[ -f "$STATE_FILE" ]] && last_level=$(cat "$STATE_FILE")

notify() {
    local urgency="$1" title="$2" body="$3" icon="$4"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -i "$icon" -a "battery-warning" "$title" "$body"
    else
        echo "[$urgency] $title: $body" >&2
    fi
}

if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
    echo "none" > "$STATE_FILE"
    exit 0
fi

current_level="ok"
if (( capacity < CRIT_THRESHOLD )); then
    current_level="critical"
elif (( capacity < WARN_THRESHOLD )); then
    current_level="warning"
fi

if [[ "$current_level" != "$last_level" ]]; then
    case "$current_level" in
        critical)
            notify critical "Battery critically low" \
                "Battery at ${capacity}%. Plug in the charger immediately!" \
                "battery-caution"
            ;;
        warning)
            notify normal "Battery low" \
                "Battery at ${capacity}%. Consider plugging in the charger." \
                "battery-low"
            ;;
    esac
    echo "$current_level" > "$STATE_FILE"
fi
