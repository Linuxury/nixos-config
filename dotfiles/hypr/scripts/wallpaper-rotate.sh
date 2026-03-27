#!/usr/bin/env bash
# scripts/wallpaper-rotate.sh — Random wallpaper at :00 and :30
# Runs in background, loops forever

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
    ~/.config/hypr/scripts/set-wallpaper.sh
done
