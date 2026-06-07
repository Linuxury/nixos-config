#!/usr/bin/env bash
# layout.sh — Waybar layout indicator and cycler
#
# Usage:
#   layout.sh          → output current workspace layout as waybar JSON
#   layout.sh cycle    → cycle to next layout and apply to current workspace
#
# Cycle order: scrolling → dwindle → master → scrolling

active_json=$(hyprctl activeworkspace -j 2>/dev/null)
LAYOUT=$(printf '%s' "$active_json" | grep -oP '"tiledLayout":\s*"\K[^"]+')
WSID=$(printf '%s'   "$active_json" | grep -oP '"id":\K\d+'       | head -1)

case "$1" in
  cycle)
    case "$LAYOUT" in
      scrolling) NEXT=dwindle  ;;
      dwindle)   NEXT=master   ;;
      master)    NEXT=scrolling;;
      *)         NEXT=dwindle  ;;
    esac
    hyprctl keyword workspace "$WSID, layout:$NEXT" > /dev/null
    exit 0
    ;;
  *)
    case "$LAYOUT" in
      scrolling) echo '{"text":"󰕴","tooltip":"Scrolling layout"}' ;;
      dwindle)   echo '{"text":"󰕰","tooltip":"Dwindle layout"}'   ;;
      master)    echo '{"text":"󱂬","tooltip":"Master layout"}'    ;;
      *)         echo '{"text":"󰕴","tooltip":"'"$LAYOUT"'"}'      ;;
    esac
    ;;
esac
