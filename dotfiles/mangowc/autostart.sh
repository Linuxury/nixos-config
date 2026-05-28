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
# Bluetooth applet — brief delay lets bluetoothd finish registering on D-Bus
# before blueman-applet tries to connect. Without this it fails silently.
(sleep 3 && run blueman-applet) &

# ---------------------------------------------------------------------------
# Clipboard history daemon
# ---------------------------------------------------------------------------
run cliphist wipe 2>/dev/null; wl-paste --watch cliphist store &

# ---------------------------------------------------------------------------
# Monitor output — max refresh rate
#
# Queries all connected outputs and selects the highest-refresh mode for each.
# Runs once at startup via wlr-randr.
# jq parses the JSON; refresh values from wlr-randr are in mHz (divide by 1000).
#
# NOTE: --adaptive-sync disabled — triggers wlr_backend_finish assertion crash
# on AMD RDNA3 (RX 7900 XTX). Same root cause as the Hyprland DPMS crash.
# ---------------------------------------------------------------------------
wlr-randr --json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read -r out; do
  name=$(printf '%s' "$out" | jq -r '.name')
  width=$(printf '%s' "$out" | jq -r '.modes | max_by(.refresh) | .width')
  height=$(printf '%s' "$out" | jq -r '.modes | max_by(.refresh) | .height')
  refresh=$(printf '%s' "$out" | jq -r '.modes | max_by(.refresh) | (.refresh / 1000 | floor)')
  wlr-randr --output "$name" \
    --mode "${width}x${height}@${refresh}" 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# Idle management — screen lock + display off
#
# sway-audio-idle-inhibit creates a zwp_idle_inhibit_manager_v1 inhibitor
# whenever PipeWire audio is active. This keeps the screen on during games
# (Proton/XWayland games can't send Wayland idle-inhibit directly, and
# xdg-desktop-portal-wlr doesn't implement the Inhibit portal interface,
# so this is the only reliable bridge).
#
# swayidle timers are suppressed while any inhibitor is held.
#
# Timeouts:
#   15 min → lock screen (swaylock)
#   20 min → displays off (wlr-randr DPMS off)
#   resume  → displays back on
#   before-sleep → lock before systemd suspend
# ---------------------------------------------------------------------------
sway-audio-idle-inhibit &

swayidle -w \
  timeout 900  'swaylock -f -c 000000' \
  timeout 1200 'wlr-randr --json | jq -r ".[].name" | xargs -I{} wlr-randr --output {} --off' \
  resume       'wlr-randr --json | jq -r ".[].name" | xargs -I{} wlr-randr --output {} --on' \
  before-sleep 'swaylock -f -c 000000' &

# ---------------------------------------------------------------------------
# Night light (color temperature by time of day)
# ---------------------------------------------------------------------------
run wlsunset -l 18.4 -L -66.1   # San Juan, PR — adjust to your location

# ---------------------------------------------------------------------------
# Polkit authentication agent
# ---------------------------------------------------------------------------
run /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1
