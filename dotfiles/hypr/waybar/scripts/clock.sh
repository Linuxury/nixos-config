#!/usr/bin/env bash
# ===========================================================================
# waybar/scripts/clock.sh — Custom clock with no leading zero on 12h hour
#
# Uses shell `date` which supports %-I (strftime), unlike waybar's built-in
# chrono formatter which only has zero-padded %I.
#
# Outputs JSON for waybar (return-type: json).
# Tooltip shows a full `cal` calendar for the current month.
# ===========================================================================

TIME=$(date +"%-I:%M %p")
DATE=$(date +"%A, %d %b %Y")
CAL=$(cal | sed 's/</\&lt;/g; s/>/\&gt;/g')

printf '{"text":"  %s   %s","tooltip":"%s"}\n' \
    "$DATE" "$TIME" "$(echo "$CAL" | awk '{printf "%s\\n", $0}')"
