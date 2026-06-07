#!/usr/bin/env bash
# col-width-apply.sh — One-shot column width adjustment for scrolling layout.
#
# Called by layout-hooks.lua on window open/destroy/workspace switch.
# Determines how many tiled windows are on the active workspace and sets
# every column to the appropriate width:
#
#   1 tiled window  → 67%
#   2+ tiled windows → 50%
#
# Brief settle delay (0.1 s) lets Hyprland finish updating its client list
# before we count — same technique as the original col-width-auto.sh daemon.

sleep 0.1

ws_json=$(hyprctl activeworkspace -j 2>/dev/null)
ws_id=$(printf '%s' "$ws_json" | jq -r '.id')
layout=$(printf '%s' "$ws_json" | jq -r '.tiledLayout // "scrolling"')

[[ "$layout" != "scrolling" ]] && exit 0
[[ -z "$ws_id" || "$ws_id" == "null" ]] && exit 0

count=$(hyprctl clients -j 2>/dev/null | \
    jq --arg ws "$ws_id" \
       '[.[] | select(.workspace.id == ($ws|tonumber)) | select(.floating == false)] | length')

if [[ "$count" -le 1 ]]; then
    ratio="0.67"
else
    ratio="0.50"
fi

focused=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')

# Resize every tiled window's column to the target ratio.
# colresize only affects the focused window's column, so we cycle focus
# through all tiled windows, resize each, then restore the original focus.
hyprctl clients -j 2>/dev/null | \
    jq -r --arg ws "$ws_id" \
       '[.[] | select(.workspace.id == ($ws|tonumber)) | select(.floating == false)] | .[].address' | \
while IFS= read -r addr; do
    [[ -z "$addr" || "$addr" == "null" ]] && continue
    hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1
    hyprctl dispatch layoutmsg "colresize $ratio"  >/dev/null 2>&1
done

[[ -n "$focused" ]] && hyprctl dispatch focuswindow "address:$focused" >/dev/null 2>&1
