#!/usr/bin/env bash
# col-width-auto.sh — Dynamic column width for scrolling layout
#
# 1 tiled window  → 67%
# 2+ tiled windows → 50% (half-and-half)
#
# Triggered by: openwindow, closewindow, workspace switch events

set_col_width() {
    local ws_json
    ws_json=$(hyprctl activeworkspace -j 2>/dev/null)

    local layout ws_id
    layout=$(printf '%s' "$ws_json" | grep -oP '"tiledLayout":\s*"\K[^"]+')
    ws_id=$(printf '%s'  "$ws_json" | grep -oP '"id":\K\d+' | head -1)

    [[ "$layout" != "scrolling" ]] && return

    local count
    count=$(hyprctl clients -j 2>/dev/null | \
        jq --arg ws "$ws_id" \
           '[.[] | select(.workspace.id == ($ws|tonumber)) | select(.floating == false)] | length')

    if [[ "$count" -le 1 ]]; then
        hyprctl dispatch layoutmsg "colresize 0.67" >/dev/null 2>&1
    else
        hyprctl dispatch layoutmsg "colresize 0.50" >/dev/null 2>&1
    fi
}

socat -U - "UNIX-CONNECT:${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock" | \
while IFS= read -r line; do
    case "$line" in
        openwindow*|closewindow*)
            sleep 0.1   # Let Hyprland settle before counting
            set_col_width
            ;;
        workspace*)
            # Re-apply correct width when switching workspaces
            set_col_width
            ;;
    esac
done
