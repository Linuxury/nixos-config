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
    ws_id=$(printf '%s'  "$ws_json" | grep -oP '"id":\s*\K\d+' | head -1)

    [[ "$layout" != "scrolling" ]] && return

    local count
    count=$(hyprctl clients -j 2>/dev/null | \
        jq --arg ws "$ws_id" \
           '[.[] | select(.workspace.id == ($ws|tonumber)) | select(.floating == false)] | length')

    local ratio
    if [[ "$count" -le 1 ]]; then
        ratio="0.67"
    else
        ratio="0.50"
    fi

    # Resize every tiled window on this workspace to the target ratio.
    # colresize only affects the focused window, so we cycle focus through
    # all tiled windows, resize each, then restore the original focus.
    local focused_addr
    focused_addr=$(hyprctl activewindow -j 2>/dev/null | grep -oP '"address":\s*"\K[^"]+')

    local addresses
    addresses=$(hyprctl clients -j 2>/dev/null | \
        jq -r --arg ws "$ws_id" \
           '[.[] | select(.workspace.id == ($ws|tonumber)) | select(.floating == false)] | .[].address')

    while IFS= read -r addr; do
        [[ -z "$addr" ]] && continue
        hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1
        hyprctl dispatch layoutmsg "colresize $ratio" >/dev/null 2>&1
    done <<< "$addresses"

    # Restore original focus
    [[ -n "$focused_addr" ]] && hyprctl dispatch focuswindow "address:$focused_addr" >/dev/null 2>&1
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
