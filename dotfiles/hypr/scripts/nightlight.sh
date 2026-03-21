#!/usr/bin/env bash
# ===========================================================================
# nightlight.sh — Toggle wlsunset night light on/off
#
# Usage: nightlight.sh [on|off|toggle]
#   on       — start wlsunset
#   off      — stop wlsunset
#   toggle   — flip state (default)
#
# Schedule: 6:00 AM → 5500K (daytime), 8:00 PM → 3500K (nighttime)
# ===========================================================================

PID_FILE="/tmp/wlsunset.pid"

case "${1:-toggle}" in
    on)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            notify-send -t 2000 "  Night Light" "Already running"
            exit 0
        fi
        wlsunset -S 06:00 -s 20:00 -t 3500 &
        echo $! > "$PID_FILE"
        notify-send -t 2000 "  Night Light" "Enabled (warm at 8 PM)"
        ;;
    off)
        if [ -f "$PID_FILE" ]; then
            kill "$(cat "$PID_FILE")" 2>/dev/null
            rm -f "$PID_FILE"
        fi
        pkill -x wlsunset 2>/dev/null
        notify-send -t 2000 "  Night Light" "Disabled"
        ;;
    toggle)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            "$0" off
        else
            "$0" on
        fi
        ;;
esac
