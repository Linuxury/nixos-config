#!/usr/bin/env bash
# ===========================================================================
# scripts/powermenu.sh — Power / session menu via wofi
#
# Options:
#   󰤄  Lock       — noctalia msg session lock
#   󰍃  Logout     — exit Hyprland (back to greetd)
#   󰒲  Suspend    — systemctl suspend
#   󰜉  Reboot     — systemctl reboot
#   󰐥  Shutdown   — systemctl poweroff
#
# Triggered by SUPER+SHIFT+E (replaces bare `exit` binding).
# Uses shared style.css — same theme as app launcher, dmenu, clipboard.
# ===========================================================================

LOCK="󰤄  Lock"
LOGOUT="󰍃  Logout"
SUSPEND="󰒲  Suspend"
REBOOT="󰜉  Reboot"
SHUTDOWN="󰐥  Shutdown"

CHOICE=$(printf '%s\n' "$LOCK" "$LOGOUT" "$SUSPEND" "$REBOOT" "$SHUTDOWN" \
    | wofi \
        --dmenu \
        --normal-window \
        --class powermenu \
        --width  320 \
        --location center \
        --style "$HOME/.config/wofi/powermenu-style.css" \
        --no-actions \
        --insensitive)

case "$CHOICE" in
    "$LOCK")     noctalia msg session lock ;;
    "$LOGOUT")   noctalia msg session logout ;;
    "$SUSPEND")  noctalia msg session suspend ;;
    "$REBOOT")   noctalia msg session reboot ;;
    "$SHUTDOWN")  noctalia msg session shutdown ;;
esac
