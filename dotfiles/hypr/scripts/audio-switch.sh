#!/usr/bin/env bash
# ===========================================================================
# audio-switch.sh — Switch audio output/input device via wofi
#
# Usage:
#   audio-switch.sh sink    — switch audio output (speakers, headphones, HDMI)
#   audio-switch.sh source  — switch audio input (microphones)
#
# Parses wpctl status, shows devices in wofi, sets selected as default.
# For Bluetooth/Internal sinks, finds the matching Audio/Sink node.
# ===========================================================================
set -euo pipefail

MODE="${1:-sink}"

if [[ "$MODE" == "sink" ]]; then
    SECTION="Sinks"
    NEXT="Sources"
    LABEL="Output Device"
    SINK_CLASS="Audio/Sink"
elif [[ "$MODE" == "source" ]]; then
    SECTION="Sources"
    NEXT="Filters"
    LABEL="Input Device"
    SINK_CLASS="Audio/Source"
else
    echo "Usage: audio-switch.sh [sink|source]" >&2
    exit 1
fi

# Get Audio section, then narrow to the right subsection
AUDIO=$(wpctl status | awk '/^Audio/,/^Video/')
DEVICES=$(echo "$AUDIO" | awk "/${SECTION}/,/${NEXT}/" | \
    grep -oP '\d+\.\s+[^\[]*' | sed 's/\s*$//')

if [[ -z "$DEVICES" ]]; then
    notify-send -t 3000 "$LABEL" "No devices found"
    exit 1
fi

# Get current default device ID
DEFAULT_ID=$(echo "$AUDIO" | awk "/${SECTION}/,/${NEXT}/" | \
    grep '*' | grep -oP '\d+' | head -1)

# Build wofi list with current default marked
WOFI_LIST=""
while IFS= read -r line; do
    ID=$(echo "$line" | grep -oP '^\d+')
    NAME=$(echo "$line" | sed 's/^[0-9]*\.\s*//')
    if [[ "$ID" == "$DEFAULT_ID" ]]; then
        WOFI_LIST+="● ${NAME}\n"
    else
        WOFI_LIST+="○ ${NAME}\n"
    fi
done <<< "$DEVICES"

# Show wofi menu
SELECTED=$(echo -e "$WOFI_LIST" | wofi --dmenu \
    --prompt "$LABEL" \
    --normal-window \
    --style ~/.config/wofi/style.css 2>/dev/null || true)

[[ -z "$SELECTED" ]] && exit 0

# Extract device name and find its ID from wpctl
SELECTED_NAME=$(echo "$SELECTED" | sed 's/^[●○] //')
SINK_ID=$(echo "$DEVICES" | grep -F "$SELECTED_NAME" | grep -oP '^\d+' | head -1)

if [[ -z "$SINK_ID" ]]; then
    notify-send -t 3000 "$LABEL" "Device not found"
    exit 1
fi

# Try setting default directly (works for ALSA devices)
if wpctl set-default "$SINK_ID" 2>/dev/null; then
    notify-send -t 2000 "$LABEL" "Switched to: $SELECTED_NAME"
    exit 0
fi

# For Bluetooth/Internal sinks: find the non-Internal Audio/Sink node
TARGET_NODE=$(pw-cli list-objects Node 2>/dev/null | awk -v name="$SELECTED_NAME" -v class="$SINK_CLASS" '
    /^	id [0-9]+/ {
        split($0, a, " ")
        id = a[2]
        gsub(/,/, "", id)
    }
    $0 ~ name {
        found = 1
    }
    found && $0 ~ class && $0 !~ /Internal/ {
        print id
        exit
    }
')

if [[ -n "$TARGET_NODE" ]]; then
    wpctl set-default "$TARGET_NODE" 2>/dev/null
    notify-send -t 2000 "$LABEL" "Switched to: $SELECTED_NAME"
else
    notify-send -t 3000 "$LABEL" "Could not switch device"
fi
