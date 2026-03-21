#!/usr/bin/env bash
# ===========================================================================
# waybar/scripts/sysinfo.sh — Combined CPU / RAM / Disk module
#
# Compact mode (default): shows only CPU% as the headline stat.
# Expanded mode (after clicking): shows all three: CPU · RAM · Disk
#
# Toggle is handled by sysinfo-toggle.sh which flips the state file
# and sends SIGRTMIN+8 to force an immediate refresh.
#
# CPU usage is calculated via /proc/stat diff against the previous reading
# cached in /tmp/waybar-cpu-prev — accurate from the 2nd call onward.
# ===========================================================================

STATE_FILE="$HOME/.local/share/waybar-sysinfo-expanded"
CPU_CACHE="/tmp/waybar-cpu-prev"

# ---------------------------------------------------------------------------
# CPU — /proc/stat diff (no sleep, uses cached previous reading)
# ---------------------------------------------------------------------------
read -r _ user nice system idle iowait irq softirq steal _ _ < /proc/stat
total=$((user + nice + system + idle + iowait + irq + softirq + steal))
idle_total=$((idle + iowait))

if [ -f "$CPU_CACHE" ]; then
    read -r prev_total prev_idle < "$CPU_CACHE"
    diff_total=$((total - prev_total))
    diff_idle=$((idle_total - prev_idle))
    if [ "$diff_total" -gt 0 ]; then
        cpu_pct=$(( (diff_total - diff_idle) * 100 / diff_total ))
    else
        cpu_pct=0
    fi
else
    cpu_pct=0
fi
echo "$total $idle_total" > "$CPU_CACHE"

# ---------------------------------------------------------------------------
# Memory
# ---------------------------------------------------------------------------
read -r mem_pct mem_used_gib mem_total_gib < <(
    free -m | awk '/Mem:/ {printf "%.0f %.1f %.1f", $3/$2*100, $3/1024, $2/1024}'
)

# ---------------------------------------------------------------------------
# Disk (root filesystem)
# ---------------------------------------------------------------------------
disk_pct=$(df / | awk 'NR==2 {printf "%.0f", $3/$2*100}')

# ---------------------------------------------------------------------------
# Tooltip — always shows all three
# ---------------------------------------------------------------------------
TOOLTIP="CPU: ${cpu_pct}%\nRAM: ${mem_used_gib}/${mem_total_gib} GiB (${mem_pct}%)\nDisk: ${disk_pct}%"

# ---------------------------------------------------------------------------
# Text — compact or expanded depending on state file
# ---------------------------------------------------------------------------
if [ -f "$STATE_FILE" ]; then
    TEXT="󰻠 ${cpu_pct}%  󰍛 ${mem_pct}%  󰋊 ${disk_pct}%"
else
    TEXT="󰻠 ${cpu_pct}%"
fi

printf '{"text":"%s","tooltip":"%s"}\n' "$TEXT" "$TOOLTIP"
