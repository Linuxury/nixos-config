#!/usr/bin/env bash
# ===========================================================================
# notify-update-result.sh — Update completion notification handler
#
# Sends desktop toast, ntfy push notification, and email (failure only).
# Delegates vault logging and PENDING.md writes to nixos-log-rebuild.
#
# Usage: notify-update-result.sh <success|failure> [log-file]
# ===========================================================================
set -euo pipefail

OUTCOME="${1:?Usage: notify-update-result.sh <success|failure> [log-file]}"
LOG_FILE="${2:-/var/log/nixos-auto-update.log}"

HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%-I:%M %p')
DATETIME="$DATE $TIME"
VAULT="${HOME}/Jarvis"

# ── Generation info ────────────────────────────────────────────────────────
GEN=$(readlink /nix/var/nix/profiles/system 2>/dev/null | \
      grep -oP 'system-\K\d+' || echo "?")
PREV_GEN=""
if [[ "$GEN" != "?" ]] && [[ "$GEN" -gt 0 ]] 2>/dev/null; then
  PREV_GEN=$((GEN - 1))
fi

# ── Vault logging + PENDING.md ────────────────────────────────────────────
# nixos-log-rebuild handles:
#   - Writing/prepending to 09 🔄 Updates/<hostname>.md
#   - Inserting failure/warning rows into PENDING.md (deduplicated)
#   - Pruning log entries older than 30 days
nixos-log-rebuild \
  --outcome "$OUTCOME" \
  --log     "$LOG_FILE" \
  --host    "$HOSTNAME" \
  --vault   "$VAULT" 2>/dev/null || true

# ── Smart error parsing ────────────────────────────────────────────────────
parse_error() {
  local log
  log=$(cat "$LOG_FILE" 2>/dev/null || echo "")

  if echo "$log" | grep -qiE "hash mismatch"; then
    local detail; detail=$(echo "$log" | grep -i "hash mismatch" | tail -1)
    printf "hash-mismatch\nHash mismatch in source fetch — flake.lock may reference a deleted commit.\nDetail: %s" "$detail"
  elif echo "$log" | grep -qiE "No such file or directory"; then
    local detail; detail=$(echo "$log" | grep -i "No such file" | tail -1)
    printf "missing-file\nFile not found during build.\nDetail: %s" "$detail"
  elif echo "$log" | grep -qiE "attribute .* missing"; then
    local detail; detail=$(echo "$log" | grep -i "attribute.*missing" | tail -1)
    printf "missing-attribute\nA Nix attribute was missing — option may have been renamed upstream.\nDetail: %s" "$detail"
  elif echo "$log" | grep -qiE "out of memory|OOM|cannot allocate"; then
    printf "out-of-memory\nBuild ran out of memory — reduce max-jobs or add swap."
  elif echo "$log" | grep -qiE "timed out|timeout|connection refused|couldn't connect"; then
    printf "network-timeout\nNetwork timeout — flaky connection or upstream server down."
  elif echo "$log" | grep -qiE "Permission denied"; then
    local detail; detail=$(echo "$log" | grep -i "Permission denied" | tail -1)
    printf "permission-denied\nPermission error — check file ownership.\nDetail: %s" "$detail"
  elif echo "$log" | grep -qiE "collision between"; then
    printf "package-collision\nPackage collision — duplicate package definitions in config."
  elif echo "$log" | grep -qiE "infinite recursion"; then
    printf "infinite-recursion\nCircular dependency in module config."
  else
    printf "unknown\nUnknown error — see log tail in email below."
  fi
}

# ── Generation diff ────────────────────────────────────────────────────────
get_diff() {
  [[ -z "$PREV_GEN" ]] && return
  local prev="/nix/var/nix/profiles/system-${PREV_GEN}-link"
  if [[ -e "$prev" && -e "/run/current-system" ]]; then
    nix store diff-closures "$prev" "/run/current-system" 2>/dev/null | \
      sed 's/\x1b\[[0-9;]*m//g' || true
  fi
}

# ── ntfy push notification ────────────────────────────────────────────────
NTFY_URL="http://media-server:2586/nixos-updates"

send_ntfy() {
  curl -s --max-time 10 \
    -H "Title: $1" -H "Priority: $2" -H "Tags: $3" \
    -d "$4" "$NTFY_URL" 2>/dev/null || true
}

# ── Desktop toast ─────────────────────────────────────────────────────────
send_toast() {
  if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    notify-send \
      --app-name "NixOS Update" --icon "$1" \
      --urgency "$2" --expire-time=20000 \
      "$3" "$4" 2>/dev/null || true
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────
case "$OUTCOME" in
  success)
    DIFF=$(get_diff || true)

    # ntfy push
    send_ntfy \
      "Update Complete — ${HOSTNAME}" \
      "default" "white_check_mark" \
      "Gen ${GEN}${PREV_GEN:+ (was ${PREV_GEN})} | ${DATETIME}"

    # Desktop toast
    send_toast \
      "system-software-update" "normal" \
      "Update Complete" \
      "Host: ${HOSTNAME} | Gen ${GEN} | ${DATETIME}"
    ;;

  failure)
    ERROR_INFO=$(parse_error)
    ERROR_TYPE=$(echo "$ERROR_INFO" | head -1)
    ERROR_SUMMARY=$(echo "$ERROR_INFO" | sed -n '2p')
    ERROR_DETAIL=$(echo "$ERROR_INFO" | sed -n '3,$p')

    DIFF=$(get_diff || true)

    # ntfy push
    send_ntfy \
      "Update FAILED — ${HOSTNAME}" \
      "urgent" "x,warning" \
      "${ERROR_TYPE}: ${ERROR_SUMMARY} | ${DATETIME}"

    # Desktop toast
    send_toast \
      "dialog-error" "critical" \
      "Update Failed" \
      "Host: ${HOSTNAME}\n${ERROR_TYPE}: ${ERROR_SUMMARY}"

    # Email — full picture: error, diff, warnings, log tail
    WARNINGS=$(grep -E "warning:" "$LOG_FILE" 2>/dev/null | \
      grep -ivE '/nix/store/[a-z0-9]{32}|\.c:[0-9]|gcc|g\+\+|cmake|fortify|implicit declaration|unused (variable|parameter)|-W[a-z]|ld: warning' | \
      grep -iE 'renamed|deprecated|removed|does not exist|unknown option|no longer supported|has been|will be removed|type error' | \
      sort -u || true)

    {
      echo "Subject: [NixOS] Update FAILED — ${HOSTNAME} — ${DATE}"
      echo "From: linuxurypr@gmail.com"
      echo "To: linuxurypr@gmail.com"
      echo "Content-Type: text/plain; charset=utf-8"
      echo ""
      echo "NixOS Auto-Update Failed"
      echo "========================"
      echo ""
      printf "Host:       %s\n" "$HOSTNAME"
      printf "Time:       %s\n" "$DATETIME"
      printf "Generation: %s (unchanged — rebuild did not complete)\n" "$GEN"
      echo ""
      echo "─── Error ───────────────────────────────────────────"
      printf "Type:    %s\n" "$ERROR_TYPE"
      printf "Summary: %s\n" "$ERROR_SUMMARY"
      if [[ -n "$ERROR_DETAIL" ]]; then
        echo ""
        echo "$ERROR_DETAIL"
      fi
      if [[ -n "$WARNINGS" ]]; then
        echo ""
        echo "─── NixOS Warnings ──────────────────────────────────"
        echo "$WARNINGS"
      fi
      if [[ -n "$DIFF" ]]; then
        echo ""
        echo "─── Package Changes (partial — build did not finish) ─"
        echo "$DIFF"
      fi
      echo ""
      echo "─── System Info ─────────────────────────────────────"
      printf "Kernel:    %s\n" "$(uname -r)"
      printf "Uptime:    %s\n" "$(uptime -p 2>/dev/null || echo N/A)"
      printf "Disk free: %s on /\n" "$(df -h / 2>/dev/null | tail -1 | awk '{print $4}' || echo N/A)"
      printf "Memory:    %s\n" "$(free -h 2>/dev/null | awk '/^Mem:/{print $3 " / " $2 " used"}' || echo N/A)"
      echo ""
      echo "─── Log (last 50 lines) ─────────────────────────────"
      tail -50 "$LOG_FILE" 2>/dev/null || echo "Log not available"
    } | msmtp linuxurypr@gmail.com 2>/dev/null || true
    ;;
esac

echo "[notify-update-result] ${OUTCOME} notification sent for ${HOSTNAME}"
