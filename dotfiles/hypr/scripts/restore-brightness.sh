#!/usr/bin/env bash
# scripts/restore-brightness.sh — Restore brightness after dim (laptops only)

DEVICE=$(brightnessctl -l 2>/dev/null | grep -m1 "backlight")
if [ -n "$DEVICE" ]; then
    brightnessctl -r
fi
