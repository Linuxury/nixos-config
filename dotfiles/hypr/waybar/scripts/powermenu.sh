#!/usr/bin/env bash
# ===========================================================================
# waybar/scripts/powermenu.sh — Power menu via wofi
#
# Shows a small wofi dmenu with four actions.
# Bound to the custom/power button in waybar.
# ===========================================================================

LOCK="  Lock"
LOGOUT="  Log Out"
RESTART="  Restart"
SHUTDOWN="  Shut Down"

CHOICE=$(printf '%s\n' "$LOCK" "$LOGOUT" "$RESTART" "$SHUTDOWN" \
    | wofi --dmenu \
           --width 220 \
           --height 215 \
           --no-actions \
           --hide-search \
           --insensitive \
           --style ~/.config/wofi/powermenu.css)

case "$CHOICE" in
    "$LOCK")     hyprlock ;;
    "$LOGOUT")   uwsm stop ;;
    "$RESTART")  systemctl reboot ;;
    "$SHUTDOWN") systemctl poweroff ;;
esac
