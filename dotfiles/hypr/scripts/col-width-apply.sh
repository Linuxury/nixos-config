#!/usr/bin/env bash
# col-width-apply.sh — One-shot column width adjustment for scrolling layout.
#
# NOTE: This script is no longer called by layout-hooks.lua — hyprctl dispatch
# is broken in Hyprland 0.55 Lua IPC mode (all dispatches wrapped as Lua,
# making space-separated args invalid syntax). Kept for reference.
#
# layout-hooks.lua now uses native hl.dispatch() calls directly.

echo "This script is not used in Lua mode — see modules/layout-hooks.lua"
