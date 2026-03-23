#!/usr/bin/env sh
# ===========================================================================
# host-overrides.sh — Per-host Hyprland settings applied at login
#
# Runs after Hyprland fully starts. Sets host-specific rules that don't
# belong in the shared config (e.g. display-dependent opacity).
# ===========================================================================

case "$HOSTNAME" in
    Ryzen5900x)
        # OLED display — pixels turn off for black, so transparency looks
        # subtle/minimal compared to LCD. Lower opacity to compensate.
        # Disable blur — on OLED, blur creates a gray frosted layer instead
        # of showing the wallpaper through cleanly.
        hyprctl keyword windowrule "match:class kitty, opacity 0.6 override 0.5 override"
        hyprctl keyword windowrule "match:class kitty, no_blur on"
        ;;
    # ThinkPad — LCD with backlight bleed, default 0.75 looks good
    # No override needed
esac
