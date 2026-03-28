#!/usr/bin/env bash
# battlenet.sh — Waybar custom module for Battle.net status
#
# Shows a clickable icon when Battle.net is running.
# Left click: focus Battle.net
# Right click: close Battle.net
#
# Only runs when Battle.net is active (exec-if in config).

CLASS="steam_app_0"
TITLE="Battle.net"

# Handle right-click close
if [ "$1" = "close" ]; then
    hyprctl dispatch closewindow class:$CLASS 2>/dev/null
    exit 0
fi

# Get Battle.net window address
WIN=$(hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
for c in json.load(sys.stdin):
    if c.get('class') == '$CLASS' and c.get('title') == '$TITLE':
        print(c['address'])
        break
" 2>/dev/null)

[ -z "$WIN" ] && exit 0

# Check if focused
FOCUSED=$(hyprctl activewindow -j 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin).get('address',''))" 2>/dev/null)

if [ "$FOCUSED" = "$WIN" ]; then
    TOOLTIP="Battle.net (focused) — Right-click to close"
else
    TOOLTIP="Battle.net — Click to focus, Right-click to close"
fi

echo "{\"text\":\"󰖵\",\"tooltip\":\"$TOOLTIP\"}"
