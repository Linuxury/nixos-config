#!/usr/bin/env bash
# scripts/wallpaper-rotate.sh — Random wallpaper at :00 and :30
# Runs in background, loops forever

has_fullscreen_game() {
    # Check if any fullscreen window is focused — skip rotation to avoid
    # disrupting games (swww transitions can steal focus and minimize them)
    local focused
    focused=$(hyprctl activewindow -j 2>/dev/null)
    echo "$focused" | grep -q '"fullscreen": true' && return 0
    return 1
}

while true; do
    now=$(date +%s)
    minute=$(date +%M)
    second=$(date +%S)

    if (( 10#$minute < 30 )); then
        # Sleep until :30
        wait=$(( (30 - 10#$minute) * 60 - 10#$second ))
    else
        # Sleep until next :00
        wait=$(( (60 - 10#$minute) * 60 - 10#$second ))
    fi

    sleep "$wait"

    if has_fullscreen_game; then
        continue
    fi

    ~/.config/hypr/scripts/set-wallpaper.sh
done
