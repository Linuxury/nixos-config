#!/usr/bin/env bash
# ===========================================================================
# compositor-dpms.sh — DPMS on/off, compositor-agnostic
#
# hypridle.conf is shared between Hyprland and Umbriel (same file, same
# ~/.config/hypr/hypridle.conf deployment — see users/linuxury/home.nix).
# Its dpms commands are the one Hyprland-specific bit; this picks the right
# one at runtime via XDG_CURRENT_DESKTOP instead of maintaining two copies.
#
# Usage: compositor-dpms.sh on|off
# ===========================================================================
set -euo pipefail

case "${XDG_CURRENT_DESKTOP:-}" in
  umbriel)   umbriel msg "dpms-$1" ;;
  Hyprland)  hyprctl dispatch dpms "$1" ;;
  *)         exit 0 ;;
esac
