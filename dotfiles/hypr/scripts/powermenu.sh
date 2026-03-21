#!/usr/bin/env bash
# ===========================================================================
# scripts/powermenu.sh — Power / session menu via wofi
#
# Options:
#   󰤄  Lock       — hyprlock
#   󰍃  Logout     — exit Hyprland (back to greetd)
#   󰒲  Suspend    — systemctl suspend
#   󰜉  Reboot     — systemctl reboot
#   󰐥  Shutdown   — systemctl poweroff
#
# Triggered by SUPER+SHIFT+E (replaces bare `exit` binding).
# Uses a separate powermenu.css so the window can be sized differently
# from the regular app launcher without touching style.css.
# ===========================================================================

LOCK="󰤄  Lock"
LOGOUT="󰍃  Logout"
SUSPEND="󰒲  Suspend"
REBOOT="󰜉  Reboot"
SHUTDOWN="󰐥  Shutdown"

CHOICE=$(printf '%s\n' "$LOCK" "$LOGOUT" "$SUSPEND" "$REBOOT" "$SHUTDOWN" \
    | wofi \
        --dmenu \
        --width  320 \
        --height 290 \
        --location center \
        --hide-search \
        --style "$HOME/.config/wofi/powermenu.css" \
        --no-actions \
        --insensitive)

case "$CHOICE" in
    "$LOCK")     hyprlock ;;
    "$LOGOUT")   hyprctl dispatch exit ;;
    "$SUSPEND")  systemctl suspend ;;
    "$REBOOT")   systemctl reboot ;;
    "$SHUTDOWN")  systemctl poweroff ;;
esac
