#!/usr/bin/env bash
# ===========================================================================
# ~/.config/mango/autostart.sh — MangoWC startup programs
#
# Runs once when MangoWC starts. Add programs here that should always
# be running in the background during a MangoWC session.
# ===========================================================================

# Helper: launch a program only if it's not already running
run() {
    pgrep -x "$1" > /dev/null || "$@" &
}

# ---------------------------------------------------------------------------
# Shell layer — bar, launcher, notifications, widgets
# ---------------------------------------------------------------------------
run noctalia-shell

# ---------------------------------------------------------------------------
# System tray applets
# ---------------------------------------------------------------------------
run nm-applet --indicator   # Network Manager tray icon
run blueman-applet          # Bluetooth tray icon

# ---------------------------------------------------------------------------
# Clipboard history daemon
# ---------------------------------------------------------------------------
run cliphist wipe 2>/dev/null; wl-paste --watch cliphist store &

# ---------------------------------------------------------------------------
# Night light (color temperature by time of day)
# ---------------------------------------------------------------------------
run wlsunset -l 18.4 -L -66.1   # San Juan, PR — adjust to your location

# ---------------------------------------------------------------------------
# Polkit authentication agent
# ---------------------------------------------------------------------------
run /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1
