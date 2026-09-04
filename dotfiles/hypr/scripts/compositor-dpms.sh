#!/usr/bin/env bash
# ===========================================================================
# compositor-dpms.sh — DPMS on/off via Noctalia (compositor-agnostic — it
# sits above both Hyprland and the parked Umbriel compositor)
#
# Usage: compositor-dpms.sh on|off
# ===========================================================================
set -euo pipefail

noctalia msg "dpms-$1"
