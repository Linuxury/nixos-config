#!/usr/bin/env bash
# ===========================================================================
# set-wallpaper.sh — Set wallpaper with swww and trigger matugen theming
#
# Usage:
#   set-wallpaper.sh [path]   — set specific wallpaper
#   set-wallpaper.sh          — pick random from ~/Pictures/Wallpapers
#
# Called by autostart.conf on login, and can be bound to a key for manual
# rotation. Sets the wallpaper, runs matugen to regenerate colors, then
# reloads waybar so the new palette takes effect immediately.
# ===========================================================================
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
LAST_FILE="$HOME/.local/share/last-matugen-wallpaper"

# Resolve wallpaper path
if [ -n "${1-}" ]; then
    WALLPAPER="$1"
else
    WALLPAPER=$(ls "$WALLPAPER_DIR"/*.{jpg,jpeg,png,webp} 2>/dev/null | shuf -n1 || true)
fi

[ -z "$WALLPAPER" ] && { echo "set-wallpaper: no wallpaper found in $WALLPAPER_DIR" >&2; exit 1; }
[ -f "$WALLPAPER" ] || { echo "set-wallpaper: file not found: $WALLPAPER" >&2; exit 1; }

# Set wallpaper via swww
swww img "$WALLPAPER" \
    --transition-type  grow \
    --transition-pos   center \
    --transition-fps   60 \
    --transition-duration 0.8

# Skip matugen if same wallpaper was already processed
LAST=$(cat "$LAST_FILE" 2>/dev/null || true)
if [ "$LAST" = "$WALLPAPER" ]; then
    exit 0
fi

# Extract dominant color — workaround for matugen 4.x "not a terminal" bug
# matugen image fails, so we use imagemagick to get the dominant color
DOMINANT_HEX=$(convert "$WALLPAPER" -resize 1x1 txt:- 2>/dev/null \
    | grep -oP '#[0-9a-fA-F]{6}' | head -1)

if [ -n "$DOMINANT_HEX" ]; then
    matugen color hex "$DOMINANT_HEX"
    echo "$WALLPAPER" > "$LAST_FILE"
else
    echo "set-wallpaper: failed to extract dominant color" >&2
fi

# Reload waybar so it picks up the new colors.css
pkill -USR2 waybar 2>/dev/null || true
