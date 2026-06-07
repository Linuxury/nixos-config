#!/usr/bin/env bash
# media-scroll.sh — Scrolling media ticker for waybar
#
# Called by waybar every second (interval: 1).
# Advances STEP chars per call — state persisted in /tmp/waybar-mpris-scroll.

DISPLAY_LEN=40
STEP=1        # characters to advance per second
PAD=8         # gap between end and restart of the loop

STATE="/tmp/waybar-mpris-scroll"

STATUS=$(playerctl status 2>/dev/null) || STATUS=""

if [[ -z "$STATUS" || "$STATUS" == "Stopped" ]]; then
    echo '{"text":""}'
    rm -f "$STATE"
    exit 0
fi

ARTIST=$(playerctl metadata artist 2>/dev/null)
TITLE=$(playerctl metadata title 2>/dev/null)

if [[ -z "$ARTIST" && -z "$TITLE" ]]; then
    echo '{"text":""}'
    exit 0
fi

[[ -n "$ARTIST" && -n "$TITLE" ]] && FULL="${ARTIST} — ${TITLE}" || FULL="${ARTIST}${TITLE}"

N=$(printf '%s' "$FULL" | awk '{print length}')

# Short enough — no scrolling needed
if (( N <= DISPLAY_LEN )); then
    [[ "$STATUS" == "Paused" ]] && p="  " || p=""
    e="${FULL//&/&amp;}"; e="${e//</&lt;}"; e="${e//>/&gt;}"; e="${e//\"/\\\"}"
    echo "{\"text\":\"${p}${e}\",\"class\":\"${STATUS,,}\"}"
    rm -f "$STATE"
    exit 0
fi

# Track identity key (first 40 chars)
TRACK_ID=$(printf '%s' "$FULL" | awk '{print substr($0,1,40)}')

# Load saved position — reset if track changed
POS=0
if [[ -f "$STATE" ]]; then
    IFS=: read -r saved_pos saved_id < "$STATE"
    [[ "$saved_id" == "$TRACK_ID" ]] && POS=$saved_pos
fi

# Build padded wrap string and extract window
PADDED="${FULL}$(printf '%*s' "$PAD" '')${FULL}"
WINDOW=$(printf '%s' "$PADDED" | awk -v p=$((POS+1)) -v l="$DISPLAY_LEN" '{print substr($0,p,l)}')

# Advance by STEP, wrap around
NEXT_POS=$(( (POS + STEP) % (N + PAD) ))
printf '%s:%s\n' "$NEXT_POS" "$TRACK_ID" > "$STATE"

[[ "$STATUS" == "Paused" ]] && p="  " || p=""
w="${WINDOW//&/&amp;}"; w="${w//</&lt;}"; w="${w//>/&gt;}"
w="${w//\\/\\\\}"; w="${w//\"/\\\"}"

echo "{\"text\":\"${p}${w}\",\"class\":\"${STATUS,,}\"}"
