#!/usr/bin/env bash
# ===========================================================================
# waybar/scripts/sysinfo-toggle.sh — Toggle sysinfo expanded/compact mode
#
# Flips the state file and signals waybar to refresh the module immediately.
# Bound to on-click in the custom/sysinfo module config.
# ===========================================================================

STATE_FILE="$HOME/.local/share/waybar-sysinfo-expanded"

if [ -f "$STATE_FILE" ]; then
    rm "$STATE_FILE"
else
    touch "$STATE_FILE"
fi

# Signal waybar to re-run sysinfo.sh immediately (signal: 8 in config)
pkill -SIGRTMIN+8 waybar
