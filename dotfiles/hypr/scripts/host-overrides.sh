#!/usr/bin/env sh
# ===========================================================================
# host-overrides.sh — Per-host Hyprland settings applied at login
#
# Runs after Hyprland fully starts. Sets host-specific rules that don't
# belong in the shared config (e.g. display-dependent opacity).
# ===========================================================================

case "$HOSTNAME" in
    Ryzen5900x)
        # OLED display — no blur (creates gray frosted layer), 90% opacity
        # keeps terminal readable with bright wallpapers
        hyprctl keyword windowrule "match:class kitty, opacity 0.9 override 0.8 override"
        hyprctl keyword windowrule "match:class kitty, no_blur on"
        ;;
    # ThinkPad — LCD with backlight bleed, default 0.75 looks good
    # No override needed
esac
