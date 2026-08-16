#!/usr/bin/env bash
# ===========================================================================
# screenshot.sh — Capture, save + copy immediately, edit on demand
#
# Usage: screenshot.sh [area|fullscreen|smart] [save|copy]
#   area        — freehand region via slurp
#   fullscreen  — focused monitor, whole screen
#   smart       — windows/monitors highlighted as click targets, still
#                 supports freehand drag; an accidental click snaps to
#                 whatever's under the cursor instead of a 2px sliver
#   save (default) — write to ~/Pictures/Screenshots, copy to clipboard,
#                     notify with an "edit" action that opens satty
#   copy           — clipboard only, no file, no notification
#
# Ported from basecamp/omarchy's omarchy-cmd-screenshot, trimmed to the
# modes actually used here (no "windows"-only mode).
# ===========================================================================

set -euo pipefail

pkill slurp && exit 0

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
MODE="${1:-area}"
PROCESSING="${2:-save}"

mkdir -p "$SCREENSHOT_DIR"

# accounting for portrait/transformed displays
JQ_MONITOR_GEO='
  def format_geo:
    .x as $x | .y as $y |
    (.width / .scale | floor) as $w |
    (.height / .scale | floor) as $h |
    .transform as $t |
    if $t == 1 or $t == 3 then
      "\($x),\($y) \($h)x\($w)"
    else
      "\($x),\($y) \($w)x\($h)"
    end;
'

get_rectangles() {
  local active_workspace
  active_workspace=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')
  hyprctl monitors -j | jq -r --arg ws "$active_workspace" "${JQ_MONITOR_GEO} .[] | select(.activeWorkspace.id == (\$ws | tonumber)) | format_geo"
  hyprctl clients -j | jq -r --arg ws "$active_workspace" '.[] | select(.workspace.id == ($ws | tonumber)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

# Keep hyprpicker alive until after grim captures so the screenshot sees the
# frozen overlay rather than live content shifting during selection.
cleanup_freeze() {
  [[ -n "${PID:-}" ]] && kill "$PID" 2>/dev/null
}
trap cleanup_freeze EXIT

case "$MODE" in
  area)
    hyprpicker -r -z >/dev/null 2>&1 &
    PID=$!
    sleep .1
    SELECTION=$(slurp 2>/dev/null) || exit 0
    ;;
  fullscreen)
    SELECTION=$(hyprctl monitors -j | jq -r "${JQ_MONITOR_GEO} .[] | select(.focused == true) | format_geo")
    ;;
  smart)
    RECTS=$(get_rectangles)
    hyprpicker -r -z >/dev/null 2>&1 &
    PID=$!
    sleep .1
    SELECTION=$(echo "$RECTS" | slurp -r 2>/dev/null) || exit 0

    # Click (not drag) → snap to whichever window/monitor contains that point
    if [[ $SELECTION =~ ^([0-9]+),([0-9]+)\ ([0-9]+)x([0-9]+)$ ]]; then
      if (( "${BASH_REMATCH[3]}" * "${BASH_REMATCH[4]}" < 20 )); then
        click_x="${BASH_REMATCH[1]}"
        click_y="${BASH_REMATCH[2]}"
        while IFS= read -r rect; do
          if [[ $rect =~ ^([0-9]+),([0-9]+)\ ([0-9]+)x([0-9]+) ]]; then
            rect_x="${BASH_REMATCH[1]}"
            rect_y="${BASH_REMATCH[2]}"
            rect_width="${BASH_REMATCH[3]}"
            rect_height="${BASH_REMATCH[4]}"
            if (( click_x >= rect_x && click_x < rect_x + rect_width && click_y >= rect_y && click_y < rect_y + rect_height )); then
              SELECTION="${rect_x},${rect_y} ${rect_width}x${rect_height}"
              break
            fi
          fi
        done <<<"$RECTS"
      fi
    fi
    ;;
  *)
    echo "Usage: screenshot.sh [area|fullscreen|smart] [save|copy]"
    exit 1
    ;;
esac

[[ -z "${SELECTION:-}" ]] && exit 0

case "$PROCESSING" in
  save)
    FILEPATH="$SCREENSHOT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
    grim -g "$SELECTION" "$FILEPATH" || exit 1
    wl-copy <"$FILEPATH"
    (
      ACTION=$(notify-send "Screenshot saved to clipboard and file" "Click to edit" -t 10000 -i "$FILEPATH" -A "default=edit")
      if [[ $ACTION == "default" ]]; then
        satty --filename "$FILEPATH" \
          --output-filename "$FILEPATH" \
          --actions-on-enter save-to-clipboard \
          --save-after-copy \
          --copy-command wl-copy
      fi
    ) >/dev/null 2>&1 &
    ;;
  copy)
    grim -g "$SELECTION" - | wl-copy
    ;;
  *)
    echo "Usage: screenshot.sh [area|fullscreen|smart] [save|copy]"
    exit 1
    ;;
esac
