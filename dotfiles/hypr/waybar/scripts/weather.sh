#!/usr/bin/env bash
# ===========================================================================
# waybar/scripts/weather.sh — Current weather from wttr.in
#
# Returns a single line: <icon> <temp>°C
# Waybar calls this every 30 minutes (interval: 1800 in config.jsonc).
# Fails silently (shows "N/A") if offline or wttr.in is unreachable.
# ===========================================================================

WEATHER=$(curl -sf --max-time 5 "wttr.in/?format=%c+%t&m" 2>/dev/null)

if [ -z "$WEATHER" ]; then
    echo "N/A"
else
    echo "$WEATHER"
fi
