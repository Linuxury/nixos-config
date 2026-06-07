#!/usr/bin/env bash
# ===========================================================================
# waybar/scripts/updates.sh — NixOS pending rebuild indicator
#
# Compares the mtime of flake.lock against /run/current-system.
# If flake.lock is newer, a rebuild is pending.
#
# Returns JSON for waybar (return-type: json):
#   { "text": "...", "tooltip": "...", "class": "ok|pending" }
#
# Waybar calls this every hour (interval: 3600 in config.jsonc).
# ===========================================================================

FLAKE_DIR="$HOME/nixos-config"
LOCK_FILE="$FLAKE_DIR/flake.lock"

LOCK_TIME=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
BUILD_TIME=$(stat -c %Y /run/current-system 2>/dev/null || echo 0)

if [ "$LOCK_TIME" -gt "$BUILD_TIME" ]; then
    printf '{"text":"󰚰  rebuild","tooltip":"flake.lock is newer than running system — run: nr","class":"pending"}\n'
else
    printf '{"text":"","class":"ok"}\n'
fi
