#!/usr/bin/env bash
# ===========================================================================
# screenshot.sh — Capture, save + copy immediately, edit on demand (Umbriel)
#
# Usage: screenshot.sh [area|fullscreen] [save|copy]
#   area        — freehand region via slurp
#   fullscreen  — whole screen
#   save (default) — write to ~/Pictures/Screenshots, copy to clipboard,
#                     notify with an "edit" action that opens satty
#   copy           — clipboard only, no file, no notification
#
# Ported from dotfiles/hypr/scripts/screenshot.sh. Two things did NOT come
# along:
#   - "smart" mode (click a window/monitor to snap-select it) relied on
#     `hyprctl monitors -j` / `hyprctl clients -j` JSON geometry dumps.
#     `umbriel outputs` / `umbriel windows` are plain text only — no
#     reliable equivalent without a lot more parsing work.
#   - fullscreen mode assumes a single output (true on Ryzen5900x today):
#     bare `grim` with no `-g`/`-o` captures every enabled output combined,
#     which only equals "the screen" on a single-monitor setup. Multi-output
#     hosts would need per-output selection — not implemented.
# ===========================================================================

set -euo pipefail

pkill slurp && exit 0

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
MODE="${1:-area}"
PROCESSING="${2:-save}"

mkdir -p "$SCREENSHOT_DIR"

# Keep hyprpicker alive until after grim captures so the screenshot sees the
# frozen overlay rather than live content shifting during selection.
cleanup_freeze() {
  if [[ -n "${PID:-}" ]]; then
    kill "$PID" 2>/dev/null || true
  fi
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
    SELECTION=""   # bare grim below captures the whole (single) output
    ;;
  *)
    echo "Usage: screenshot.sh [area|fullscreen] [save|copy]"
    exit 1
    ;;
esac

[[ "$MODE" == "area" && -z "${SELECTION:-}" ]] && exit 0

case "$PROCESSING" in
  save)
    FILEPATH="$SCREENSHOT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
    if [[ -n "$SELECTION" ]]; then
      grim -g "$SELECTION" "$FILEPATH" || exit 1
    else
      grim "$FILEPATH" || exit 1
    fi
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
    if [[ -n "$SELECTION" ]]; then
      grim -g "$SELECTION" - | wl-copy
    else
      grim - | wl-copy
    fi
    ;;
  *)
    echo "Usage: screenshot.sh [area|fullscreen] [save|copy]"
    exit 1
    ;;
esac
