#!/usr/bin/env bash
# ===========================================================================
# nixos-log-rebuild — Post-rebuild warning capture and update logging
#
# Extracts actionable NixOS warnings from a rebuild log, writes them as
# deduplicated table rows in PENDING.md (⚡ Next section), and prepends a
# timestamped entry to the per-host update log at:
#   ~/Obsidian/09 🔄 Updates/<hostname>.md
#
# Log entries are automatically pruned to the last 30 days.
#
# Usage:
#   nixos-log-rebuild --outcome <success|failure> \
#                     --log     <logfile>          \
#                     [--host   <hostname>]         \
#                     [--vault  <vault-path>]
#
# Called by:
#   - notify-update-result.sh  (auto-update: session-start + weekly timer)
#   - dotfiles/zsh/zshrc       (manual: nr, nru, nrb, nrt)
# ===========================================================================
set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────────────────
OUTCOME="" LOG_FILE="" HOST="" VAULT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --outcome) OUTCOME="$2"; shift 2 ;;
    --log)     LOG_FILE="$2"; shift 2 ;;
    --host)    HOST="$2";     shift 2 ;;
    --vault)   VAULT="$2";    shift 2 ;;
    *) echo "nixos-log-rebuild: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$OUTCOME" && -n "$LOG_FILE" ]] || {
  echo "Usage: nixos-log-rebuild --outcome <success|failure> --log <logfile>" >&2
  exit 1
}

HOST="${HOST:-$(hostname)}"
VAULT="${VAULT:-$HOME/Obsidian}"

# Skip silently if vault not present (headless servers, first boot)
[[ -d "$VAULT" ]] || exit 0
[[ -f "$LOG_FILE" ]] || exit 0

PENDING="$VAULT/00 📌 Quick Access/PENDING.md"
UPDATES_DIR="$VAULT/09 🔄 Updates"
UPDATES_FILE="$UPDATES_DIR/${HOST}.md"
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')
CUTOFF=$(date -d "30 days ago" '+%Y-%m-%d' 2>/dev/null || \
         date -v-30d '+%Y-%m-%d' 2>/dev/null || echo "1970-01-01")

mkdir -p "$UPDATES_DIR"

# ── Generation info ────────────────────────────────────────────────────────
GEN=$(readlink /nix/var/nix/profiles/system 2>/dev/null | \
      grep -oP 'system-\K\d+' || echo "?")

PREV_GEN=""
if [[ "$GEN" != "?" ]] && [[ "$GEN" -gt 0 ]] 2>/dev/null; then
  PREV_GEN=$((GEN - 1))
fi

# ── Generation diff (success only) ────────────────────────────────────────
get_diff() {
  [[ -z "$PREV_GEN" ]] && return
  local prev="/nix/var/nix/profiles/system-${PREV_GEN}-link"
  local curr="/run/current-system"
  if [[ -e "$prev" && -e "$curr" ]]; then
    nix store diff-closures "$prev" "$curr" 2>/dev/null | \
      tail -20 | sed 's/\x1b\[[0-9;]*m//g' || true
  fi
}

# ── Extract actionable warnings ────────────────────────────────────────────
# Keep NixOS config/module-level warnings.
# Filter out C/C++/cmake/linker build noise — those are upstream pkg issues.
WARNINGS=$(grep -E "warning:" "$LOG_FILE" 2>/dev/null | \
  grep -ivE \
    '/nix/store/[a-z0-9]{32}|\.c:[0-9]|\.cpp:[0-9]|\.h:[0-9]|gcc|g\+\+|clang\+\+|cmake|fortify|implicit declaration|unused (variable|parameter|function|result)|-W[a-z]|ld: warning|linker warning' | \
  grep -iE \
    'renamed|deprecated|removed|does not exist|unknown option|no longer supported|has been|will be removed|type error|infinite recursion|undefined variable|is not defined' | \
  sed 's/^[[:space:]]*//' | \
  sort -u || true)

# ── Insert row into PENDING.md ⚡ Next table (deduplicated) ────────────────
pending_insert() {
  local row="$1"
  [[ -f "$PENDING" ]] || return 0

  # Extract the key text (3rd column) for dedup check
  local key
  key=$(echo "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
  grep -qF "$key" "$PENDING" 2>/dev/null && return 0

  # Insert after the |---| separator line in the ⚡ Next section
  awk -v row="$row" '
    BEGIN { in_next=0; inserted=0 }
    /^## ⚡ Next/        { in_next=1 }
    /^## / && !/⚡ Next/ { in_next=0 }
    in_next && !inserted && /^\|[-|: ]+\|$/ {
      print; print row; inserted=1; next
    }
    { print }
  ' "$PENDING" > "${PENDING}.tmp" && mv "${PENDING}.tmp" "$PENDING"
}

# Failure row
if [[ "$OUTCOME" == "failure" ]]; then
  pending_insert "| NixOS failure — ${HOST} | nixos-rebuild failed — see \`09 🔄 Updates/${HOST}.md\` | ${DATE} |"
fi

# Warning rows (one per warning, deduplicated)
if [[ -n "$WARNINGS" ]]; then
  while IFS= read -r w; do
    short=$(echo "$w" | sed 's/^warning:[[:space:]]*//' | cut -c1-80)
    pending_insert "| NixOS warning — ${HOST} | ${short} | ${DATE} |"
  done <<< "$WARNINGS"
fi

# ── Initialize host update log ────────────────────────────────────────────
if [[ ! -f "$UPDATES_FILE" ]]; then
  cat > "$UPDATES_FILE" << EOF
---
type: update-log
host: ${HOST}
---

# NixOS Updates — ${HOST}

## 📋 Log (last 30 days)

EOF
fi

# ── Prepend new log entry ─────────────────────────────────────────────────
STATUS_ICON="✅"
[[ "$OUTCOME" == "failure" ]] && STATUS_ICON="❌"

LOG_HEADER_LINE=$(grep -n "^## 📋 Log" "$UPDATES_FILE" | head -1 | cut -d: -f1)

if [[ -n "$LOG_HEADER_LINE" ]]; then
  {
    head -n "$LOG_HEADER_LINE" "$UPDATES_FILE"
    echo ""
    echo "### ${DATE} ${TIME} — ${STATUS_ICON} ${OUTCOME} — gen ${GEN}${PREV_GEN:+ (was ${PREV_GEN})}"

    if [[ -n "$WARNINGS" ]]; then
      WARN_COUNT=$(echo "$WARNINGS" | wc -l)
      echo "**Warnings (${WARN_COUNT}):**"
      while IFS= read -r w; do
        echo "- $w"
      done <<< "$WARNINGS"
    fi

    if [[ "$OUTCOME" == "success" ]]; then
      DIFF=$(get_diff || true)
      if [[ -n "$DIFF" ]]; then
        echo "**Changes:**"
        echo '```'
        echo "$DIFF"
        echo '```'
      fi
    fi

    echo ""
    tail -n "+$((LOG_HEADER_LINE + 1))" "$UPDATES_FILE"
  } > "${UPDATES_FILE}.tmp" && mv "${UPDATES_FILE}.tmp" "$UPDATES_FILE"
fi

# ── Prune entries older than 30 days ──────────────────────────────────────
awk -v cutoff="$CUTOFF" '
  /^## 📋 Log/ { in_log=1 }
  in_log && /^### [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)
    d = substr($0, RSTART, RLENGTH)
    skip = (d < cutoff) ? 1 : 0
  }
  !skip { print }
' "$UPDATES_FILE" > "${UPDATES_FILE}.tmp" && mv "${UPDATES_FILE}.tmp" "$UPDATES_FILE"

echo "nixos-log-rebuild: ${OUTCOME} logged for ${HOST} (gen ${GEN})"
