#!/usr/bin/env bash
# scripts/wallpaper-rotate.sh — Random wallpaper every 10 minutes
# Runs in background, loops forever

while true; do
    sleep 600
    ~/.config/hypr/scripts/set-wallpaper.sh
done
