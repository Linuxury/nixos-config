#!/usr/bin/env bash
# volume-osd.sh — Volume control with swayosd center-bottom OSD
# Usage: volume-osd.sh [up|down|mute|input-up|input-down|input-mute]

case "$1" in
    up)
        swayosd-client --output-volume raise
        ;;
    down)
        swayosd-client --output-volume lower
        ;;
    mute)
        swayosd-client --output-volume mute-toggle
        ;;
    input-up)
        swayosd-client --input-volume raise
        ;;
    input-down)
        swayosd-client --input-volume lower
        ;;
    input-mute)
        swayosd-client --input-volume mute-toggle
        ;;
    *)
        echo "Usage: $0 [up|down|mute|input-up|input-down|input-mute]"
        exit 1
        ;;
esac
