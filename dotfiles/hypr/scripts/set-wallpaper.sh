#!/usr/bin/env bash
# ===========================================================================
# set-wallpaper.sh — Set wallpaper with awww and trigger matugen theming
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
LOG="$HOME/.local/share/wallpaper-service.log"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# Parse flags — --force overrides the fullscreen game check
FORCE=false
WALLPAPER_PATH=""
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        *)       WALLPAPER_PATH="$arg" ;;
    esac
done

# Skip if ANY window is fullscreen — awww transitions can steal GPU/focus
# and cause games or apps to close. Use --force flag to override.
# Note: Hyprland reports fullscreen as an integer (0/1/2), not a boolean.
if [ "$FORCE" != true ]; then
    if hyprctl clients -j 2>/dev/null | grep -qP '"fullscreen":\s*[1-9]'; then
        log "SKIP fullscreen active"
        exit 0
    fi
fi

# Resolve wallpaper path
if [ -n "$WALLPAPER_PATH" ]; then
    WALLPAPER="$WALLPAPER_PATH"
else
    WALLPAPER=$(ls "$WALLPAPER_DIR"/*.{jpg,jpeg,png,webp} 2>/dev/null | shuf -n1 || true)
fi

[ -z "$WALLPAPER" ] && { echo "set-wallpaper: no wallpaper found in $WALLPAPER_DIR" >&2; exit 1; }
[ -f "$WALLPAPER" ] || { echo "set-wallpaper: file not found: $WALLPAPER" >&2; exit 1; }

# Set wallpaper via awww with random transition
TRANSITIONS=(fade left right top bottom wipe)
TRANSITION=$(shuf -n1 -e "${TRANSITIONS[@]}")

awww img "$WALLPAPER" \
    --transition-type  "$TRANSITION" \
    --transition-fps   60 \
    --transition-duration 0.8

# Skip matugen if same wallpaper was already processed.
# Compare by inode (not path) — ~/Pictures/Wallpapers is a symlink to
# ~/nixos-config/assets/Wallpapers/<dir>, so awww may report a different
# path than what we passed in, even for the same file.
LAST=$(cat "$LAST_FILE" 2>/dev/null || true)
same_file() {
    [ -f "$1" ] && [ -f "$2" ] && \
    [ "$(stat -c '%d:%i' "$1" 2>/dev/null)" = "$(stat -c '%d:%i' "$2" 2>/dev/null)" ]
}
if same_file "$WALLPAPER" "$LAST"; then
    log "SKIP same file: $(basename "$WALLPAPER")"
    exit 0
fi
log "RUN matugen: $(basename "$WALLPAPER") (last: $(basename "$LAST"))"

# Extract dominant color — workaround for matugen 4.x "not a terminal" bug
# matugen image fails, so we use imagemagick to get the dominant color.
# The || DOMINANT_HEX="" prevents set -e from exiting when grep finds no
# match (pipefail causes a non-zero exit even though convert succeeded).
DOMINANT_HEX=$(convert "$WALLPAPER" -resize 1x1 txt:- 2>/dev/null \
    | grep -oP '#[0-9a-fA-F]{6}' | head -1) || DOMINANT_HEX=""

if [ -n "$DOMINANT_HEX" ]; then
    log "COLOR #$DOMINANT_HEX"
    # Record wallpaper before running matugen so that if matugen fails,
    # set -e doesn't leave LAST_FILE pointing at a previous wallpaper and
    # cause every subsequent rotation to re-attempt (and fail) forever.
    echo "$WALLPAPER" > "$LAST_FILE"
    matugen color hex "$DOMINANT_HEX" || log "WARN matugen failed"

    # Expose current wallpaper to cosmic-greeter (can't read ~/Pictures/).
    # Hardlink avoids copying data; falls back to cp if cross-filesystem.
    ln -f "$WALLPAPER" /var/lib/wallpapers/current.jpg 2>/dev/null || \
        cp -f "$WALLPAPER" /var/lib/wallpapers/current.jpg 2>/dev/null || true
    log "DONE"
else
    log "WARN no dominant color extracted from $WALLPAPER"
fi

# NOTE: waybar reload is handled by matugen's post_hook in config.toml
# (pkill -USR2 waybar). Do NOT send a duplicate signal here — it causes
# crashes when waybar receives USR2 while still reloading CSS.
