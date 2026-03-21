#!/usr/bin/env bash
# scripts/dim-screen.sh — Dim screen if backlight device exists (laptops only)
# Skips silently on desktops where brightnessctl has no backlight device.

DEVICE=$(brightnessctl -l 2>/dev/null | grep -m1 "backlight")
if [ -n "$DEVICE" ]; then
    brightnessctl -s set 30
fi
