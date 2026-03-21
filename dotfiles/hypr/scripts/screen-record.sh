#!/usr/bin/env bash
# ===========================================================================
# screen-record.sh — Toggle screen recording with wf-recorder
#
# Usage: screen-record.sh [area|fullscreen]
#   area        — select region with slurp (default)
#   fullscreen  — record entire screen
#
# Press keybind again to stop recording.
# Saves to ~/Videos/Screen Recordings/recording-YYYYMMDD-HHMMSS.mp4
# ===========================================================================

set -euo pipefail

RECORD_DIR="$HOME/Videos/Screen Recordings"
PID_FILE="/tmp/screen-record.pid"
MODE="${1:-area}"

# If already recording, stop it
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill -INT "$PID"
        rm -f "$PID_FILE"
        notify-send -t 3000 "  Recording Saved" "$(ls -t "$RECORD_DIR"/recording-*.mp4 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo 'recording.mp4')"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

mkdir -p "$RECORD_DIR"
FILENAME="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S).mp4"

# Build wf-recorder command
case "$MODE" in
    area)
        GEOMETRY=$(slurp 2>/dev/null) || exit 1
        wf-recorder -g "$GEOMETRY" -f "$FILENAME" &
        ;;
    fullscreen)
        wf-recorder -f "$FILENAME" &
        ;;
    *)
        echo "Usage: screen-record.sh [area|fullscreen]"
        exit 1
        ;;
esac

PID=$!
echo "$PID" > "$PID_FILE"
notify-send -t 3000 "  Recording Started" "Press keybind again to stop"
