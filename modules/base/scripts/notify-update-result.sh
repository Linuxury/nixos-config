#!/usr/bin/env bash
# ===========================================================================
# notify-update-result.sh — Central update notification handler
#
# Writes Obsidian entries, sends desktop toast, emails on failure.
# Called by nixos-auto-update (session start) and via systemd
# onFailure/onSuccess hooks for weekly schedule.
#
# Usage: notify-update-result.sh <success|failure> [log-file]
# ===========================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
OUTCOME="${1:?Usage: notify-update-result.sh <success|failure> [log-file]}"
LOG_FILE="${2:-/var/log/nixos-auto-update.log}"

# ---------------------------------------------------------------------------
# System info
# ---------------------------------------------------------------------------
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%-I:%M %p')
DATETIME="$DATE $TIME"
SLUG_DATE=$(date '+%Y%m%d')

# ---------------------------------------------------------------------------
# Obsidian vault path
# Syncthing syncs ~/Obsidian across all hosts. The notify-vault service
# always runs as linuxury, so this path is consistent everywhere.
# ---------------------------------------------------------------------------
VAULT="/home/linuxury/Obsidian"

# Ensure vault directory exists
mkdir -p "$VAULT/04 ⏳ Pending" "$VAULT/05 📋 Activity Log" 2>/dev/null || true

# ---------------------------------------------------------------------------
# NixOS generation info
# ---------------------------------------------------------------------------
get_generation() {
  # Read the active system profile symlink directly — reliable, no parsing needed.
  # /nix/var/nix/profiles/system -> system-285-link  →  extracts "285"
  readlink /nix/var/nix/profiles/system 2>/dev/null | grep -oP 'system-\K\d+' || echo "unknown"
}

get_previous_generation() {
  local current
  current=$(get_generation)
  if [ "$current" != "unknown" ] && [ "$current" -gt 0 ] 2>/dev/null; then
    echo $((current - 1))
  else
    echo "unknown"
  fi
}

GENERATION=$(get_generation)
PREV_GENERATION=$(get_previous_generation)

# ---------------------------------------------------------------------------
# Generation diff (what changed between generations)
# ---------------------------------------------------------------------------
get_diff_summary() {
  if [ "$GENERATION" = "unknown" ] || [ "$PREV_GENERATION" = "unknown" ]; then
    echo "N/A"
    return
  fi

  local prev_profile="/nix/var/nix/profiles/system-${PREV_GENERATION}-link"
  local curr_profile="/run/current-system"

  if [ -e "$prev_profile" ] && [ -e "$curr_profile" ]; then
    nix store diff-closures "$prev_profile" "$curr_profile" 2>/dev/null | \
      tail -20 | sed 's/\x1b\[[0-9;]*m//g' || echo "diff unavailable"
  else
    echo "N/A"
  fi
}

# ---------------------------------------------------------------------------
# Smart error parsing — extract human-readable summary from log
# ---------------------------------------------------------------------------
parse_error() {
  local log_content
  log_content=$(cat "$LOG_FILE" 2>/dev/null || echo "")

  if echo "$log_content" | grep -qiE "hash mismatch"; then
    local details
    details=$(echo "$log_content" | grep -i "hash mismatch" | tail -1)
    echo "hash-mismatch"
    echo "Hash mismatch in source fetch."
    echo "Likely cause: flake.lock references a force-pushed or GC'd commit."
    echo "Suggested fix: nix flake update && sudo nixos-rebuild switch --flake ~/nixos-config"
    echo ""
    echo "Detail: $details"
  elif echo "$log_content" | grep -qiE "No such file or directory"; then
    local details
    details=$(echo "$log_content" | grep -i "No such file" | tail -1)
    echo "missing-file"
    echo "File not found during build."
    echo "Likely cause: renamed or moved file in upstream or local config."
    echo "Suggested fix: Check the file path in the error below."
    echo ""
    echo "Detail: $details"
  elif echo "$log_content" | grep -qiE "attribute .* missing"; then
    local details
    details=$(echo "$log_content" | grep -i "attribute.*missing" | tail -1)
    echo "missing-attribute"
    echo "Nix attribute missing."
    echo "Likely cause: Module option renamed or removed upstream."
    echo "Suggested fix: Check NixOS release notes for the renamed option."
    echo ""
    echo "Detail: $details"
  elif echo "$log_content" | grep -qiE "out of memory|OOM|cannot allocate"; then
    echo "oom"
    echo "Out of memory during build."
    echo "Likely cause: Too many parallel build jobs."
    echo "Suggested fix: Reduce nix.settings.max-jobs or add swap."
  elif echo "$log_content" | grep -qiE "timed out|timeout|connection refused|couldn't connect"; then
    echo "timeout"
    echo "Network timeout during build."
    echo "Likely cause: Flaky network or upstream server down."
    echo "Suggested fix: Retry later or check network connectivity."
  elif echo "$log_content" | grep -qiE "Permission denied"; then
    local details
    details=$(echo "$log_content" | grep -i "Permission denied" | tail -1)
    echo "permission"
    echo "Permission denied."
    echo "Likely cause: File ownership or permissions issue."
    echo "Suggested fix: Check file ownership in the error below."
    echo ""
    echo "Detail: $details"
  elif echo "$log_content" | grep -qiE "collision between"; then
    echo "conflict"
    echo "Package collision detected."
    echo "Likely cause: Duplicate package definitions."
    echo "Suggested fix: Check for conflicting module imports."
  elif echo "$log_content" | grep -qiE "infinite recursion"; then
    echo "eval-stuck"
    echo "Infinite recursion in Nix evaluation."
    echo "Likely cause: Circular dependency in module configuration."
    echo "Suggested fix: Check recent config changes for circular references."
  else
    echo "unknown"
    echo "Unknown error — see log tail below."
    # Show last 10 lines as context
    echo ""
    echo "$log_content" | tail -10
  fi
}

# ---------------------------------------------------------------------------
# Parse rename/deprecation warnings from rebuild output
# NixOS emits these when an option or package has been renamed upstream.
# They appear even on successful rebuilds — catch them on both paths.
# ---------------------------------------------------------------------------
parse_rename_warnings() {
  grep -iE \
    "warning:.*has been renamed|warning:.*renamed to|warning:.*deprecated|warning:.*no longer supported|warning:.*has been removed" \
    "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Write Obsidian pending item for rename/deprecation warnings
# The AI will see this at next session start and fix the option names.
# ---------------------------------------------------------------------------
write_obsidian_rename_warning() {
  local warnings="$1"
  local pending_file="$VAULT/04 ⏳ Pending/nixos-rename-warning-${HOSTNAME}-${DATE}.md"

  cat > "$pending_file" << EOF
---
type: pending
date: ${DATE}
status: pending
priority: medium
tags: [pending, nixos-config, rename-warning]
project: NixOS-Config
---

# NixOS Option Rename Warning — ${HOSTNAME} — ${DATE}

One or more option or package rename warnings were detected during rebuild on **${HOSTNAME}**.
The nixos-config must be updated to use the new names before the old ones are removed upstream.

## Warnings detected

\`\`\`
${warnings}
\`\`\`

## What to do
- [ ] Find each affected option in \`~/nixos-config/\`
- [ ] Rename to the new option name shown in the warning
- [ ] Run \`nixos-rebuild dry-build --flake .#${HOSTNAME}\` to verify no errors
- [ ] Commit and push so all hosts pick up the fix on next update

## Context
- **Host:** ${HOSTNAME}
- **Date:** ${DATE}
- **Rebuild outcome:** ${OUTCOME}
- **Project:** \`07 🚀 Projects/NixOS-Config.md\`
EOF
}

# ---------------------------------------------------------------------------
# Write Obsidian activity log entry
# ---------------------------------------------------------------------------
write_obsidian_log() {
  local status="$1"
  local log_file="$VAULT/05 📋 Activity Log/${DATE} - $(date '+%H%M') - nixos-update-${status}.md"
  local icon="✅"
  local error_section=""

  [ "$status" = "failed" ] && icon="❌"

  if [ "$status" = "failed" ]; then
    local error_info
    error_info=$(parse_error)
    local error_type error_summary
    error_type=$(echo "$error_info" | head -1)
    error_summary=$(echo "$error_info" | sed -n '2p')

    # Get log tail for the error section
    local log_tail
    log_tail=$(tail -30 "$LOG_FILE" 2>/dev/null || echo "Log not available")

    error_section="
## Error details
- **Type:** ${error_type}
- **Summary:** ${error_summary}

### Smart parse
$(echo "$error_info" | sed -n '3,$p')

### Log tail (last 30 lines)
\`\`\`
${log_tail}
\`\`\`"
  fi

  cat > "$log_file" << EOF
---
type: log
date: ${DATE}
time: ${TIME}
ai: system
tags: [log, auto-update$([ "$status" = "failed" ] && echo ", error")]
---

# ${DATE} — NixOS Update (${icon} ${status^})

## What happened
Automatic NixOS update ${status} on **${HOSTNAME}**.

## Details
- **Host:** ${HOSTNAME}
- **Trigger:** Session start / weekly schedule
- **Generation:** ${GENERATION}${PREV_GENERATION:+ (was ${PREV_GENERATION})}
$(if [ "$status" = "success" ]; then
echo "- **Changes:**"
echo '```'
get_diff_summary
echo '```'
fi)
${error_section}
## Related
- Project: \`07 🚀 Projects/NixOS-Config.md\`
$(if [ "$status" = "failed" ]; then
echo "- Pending: \`04 ⏳ Pending/nixos-update-failed-${DATE}.md\`"
fi)
EOF
}

# ---------------------------------------------------------------------------
# Write Obsidian pending item (failure only)
# ---------------------------------------------------------------------------
write_obsidian_pending() {
  local pending_file="$VAULT/04 ⏳ Pending/nixos-update-failed-${DATE}.md"
  local error_info
  error_info=$(parse_error)
  local error_type error_summary
  error_type=$(echo "$error_info" | head -1)
  error_summary=$(echo "$error_info" | sed -n '2p')

  cat > "$pending_file" << EOF
---
type: pending
date: ${DATE}
status: pending
priority: high
tags: [pending, auto-update, error]
project: NixOS-Config
---

# NixOS Update Failed — ${HOSTNAME} — ${DATE}

## Error
- **Type:** ${error_type}
- **Summary:** ${error_summary}

## Smart parse
$(echo "$error_info" | sed -n '3,$p')

## Log tail (last 20 lines)
\`\`\`
$(tail -20 "$LOG_FILE" 2>/dev/null || echo "Log not available")
\`\`\`

## What the AI should check
- [ ] Is this a transient upstream issue? (retry later)
- [ ] Does flake.lock need updating?
- [ ] Are there other inputs with similar issues?
- [ ] Was there a breaking change in the update?

## Related
- Activity log: \`05 📋 Activity Log/${DATE} - $(date '+%H%M') - nixos-update-failed.md\`
- Project: \`07 🚀 Projects/NixOS-Config.md\`
EOF
}

# ---------------------------------------------------------------------------
# Desktop notification (notify-send)
# ---------------------------------------------------------------------------
send_desktop_notification() {
  local title="$1"
  local body="$2"
  local icon="$3"
  local urgency="${4:-normal}"
  local expire="${5:---expire-time=5000}"

  # Only send if display is available (desktop session)
  if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    notify-send \
      --app-name "NixOS Update" \
      --icon "$icon" \
      --urgency "$urgency" \
      $expire \
      "$title" \
      "$body" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Push notification via self-hosted ntfy (media-server:2586)
#
# All hosts send to the same topic — subscribe once on phone/desktop.
# Phone: install ntfy app → set server to http://<media-server-tailscale-ip>:2586
#        → subscribe to topic: nixos-updates
# Desktop: http://media-server:2586 → subscribe to nixos-updates
#
# Priority levels: min low default high urgent
# Tag names: https://docs.ntfy.sh/emojis/
# ---------------------------------------------------------------------------
NTFY_URL="http://media-server:2586/nixos-updates"

send_ntfy() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"
  local tags="${4:-}"

  local curl_args=(
    -s --max-time 10
    -H "Title: ${title}"
    -H "Priority: ${priority}"
    -d "${message}"
  )
  [ -n "$tags" ] && curl_args+=( -H "Tags: ${tags}" )

  curl "${curl_args[@]}" "$NTFY_URL" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Email notification (msmtp — failure only)
# ---------------------------------------------------------------------------
send_email() {
  local subject="$1"
  local body="$2"

  # Only send if msmtp is available
  if command -v msmtp &>/dev/null || command -v sendmail &>/dev/null; then
    {
      echo "Subject: ${subject}"
      echo "From: linuxurypr@gmail.com"
      echo "To: linuxurypr@gmail.com"
      echo "Content-Type: text/plain; charset=utf-8"
      echo ""
      echo "$body"
    } | msmtp linuxurypr@gmail.com 2>/dev/null || \
      echo "WARNING: Failed to send email notification" >&2
  fi
}

# ---------------------------------------------------------------------------
# Build email body for failures
# ---------------------------------------------------------------------------
build_failure_email_body() {
  local error_info
  error_info=$(parse_error)
  local error_type error_summary
  error_type=$(echo "$error_info" | head -1)
  error_summary=$(echo "$error_info" | sed -n '2p')

  cat << EOF
NixOS Auto-Update Failed
=========================

Host:       ${HOSTNAME}
Time:       ${DATETIME}
Trigger:    Session start / weekly schedule
Generation: ${GENERATION} (unchanged)

Error Summary
-------------
Type: ${error_type}
${error_summary}

Smart Parse
-----------
$(echo "$error_info" | sed -n '3,$p')

Full Rebuild Log (last 60 lines)
---------------------------------
$(tail -60 "$LOG_FILE" 2>/dev/null || echo "Log not available")

System Info
-----------
Kernel:     $(uname -r)
Uptime:     $(uptime -p 2>/dev/null || echo "N/A")
Disk free:  $(df -h / 2>/dev/null | tail -1 | awk '{print $4}' || echo "N/A") available on /
Memory:     $(free -h 2>/dev/null | awk '/^Mem:/{print $3 " / " $2 " used"}' || echo "N/A")
EOF
}

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------
case "$OUTCOME" in
  success)
    # Obsidian log
    write_obsidian_log "success" 2>/dev/null || echo "WARNING: Failed to write Obsidian log" >&2

    # Rename warnings — appear even on successful rebuilds
    RENAME_WARNINGS=$(parse_rename_warnings)
    if [ -n "$RENAME_WARNINGS" ]; then
      write_obsidian_rename_warning "$RENAME_WARNINGS" 2>/dev/null || \
        echo "WARNING: Failed to write rename warning pending" >&2
    fi

    # Push notification (all hosts — reaches phone + desktop)
    send_ntfy \
      "Update Complete — ${HOSTNAME}" \
      "Generation ${GENERATION} (was ${PREV_GENERATION}) | ${DATETIME}" \
      "default" \
      "white_check_mark"

    # Desktop notification (local machine only)
    send_desktop_notification \
      "Update Complete" \
      "Host: ${HOSTNAME} | Generation ${GENERATION}\n${DATETIME}" \
      "system-software-update" \
      "normal" \
      "--expire-time=20000"
    ;;

  failure)
    # Obsidian log + pending
    write_obsidian_log "failed" 2>/dev/null || echo "WARNING: Failed to write Obsidian log" >&2
    write_obsidian_pending 2>/dev/null || echo "WARNING: Failed to write Obsidian pending" >&2

    # Rename warnings — may appear even on failures (partial eval before error)
    RENAME_WARNINGS=$(parse_rename_warnings)
    if [ -n "$RENAME_WARNINGS" ]; then
      write_obsidian_rename_warning "$RENAME_WARNINGS" 2>/dev/null || \
        echo "WARNING: Failed to write rename warning pending" >&2
    fi

    # Parse error for notification
    local_error_info=$(parse_error)
    local_error_type=$(echo "$local_error_info" | head -1)
    local_error_summary=$(echo "$local_error_info" | sed -n '2p')

    # Push notification (urgent — reaches phone + desktop from any host)
    send_ntfy \
      "Update FAILED — ${HOSTNAME}" \
      "${local_error_type}: ${local_error_summary} | ${DATETIME}" \
      "urgent" \
      "x,warning"

    # Desktop notification (local machine only)
    send_desktop_notification \
      "Update Failed" \
      "Host: ${HOSTNAME} | ${local_error_type}\n${local_error_summary}" \
      "dialog-error" \
      "critical" \
      "--expire-time=20000"

    # Email
    send_email \
      "[NixOS] Update FAILED — ${HOSTNAME} — ${DATE}" \
      "$(build_failure_email_body)"
    ;;

  *)
    echo "Usage: notify-update-result.sh <success|failure> [log-file]" >&2
    exit 1
    ;;
esac

echo "[notify-update-result] ${OUTCOME} notification sent for ${HOSTNAME}"
