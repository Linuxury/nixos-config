#!/usr/bin/env bash
# volume-osd.sh — Volume control via wpctl (DMS shows its own OSD via pipewire events)
# Usage: volume-osd.sh [up|down|mute|input-up|input-down|input-mute]

case "$1" in
    up)
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    input-up)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ 5%+
        ;;
    input-down)
        wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
        ;;
    input-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    *)
        echo "Usage: $0 [up|down|mute|input-up|input-down|input-mute]"
        exit 1
        ;;
esac
