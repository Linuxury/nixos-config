#!/usr/bin/env bash
# scripts/wallpaper-rotate.sh — Random wallpaper at :00 and :30
# Runs in background, loops forever

has_fullscreen_game() {
    # Check if ANY window is fullscreen — skip rotation to avoid disrupting
    # games (awww transitions can steal GPU/focus and close them).
    # Uses clients (all windows) not activewindow (focused only).
    # Hyprland reports fullscreen as an integer: 0=none, 1=full, 2=fake.
    hyprctl clients -j 2>/dev/null | grep -qP '"fullscreen":\s*[1-9]'
}

# On startup: check if colors are in sync with the current awww wallpaper.
# awww restores its last wallpaper on daemon restart, but set-wallpaper.sh
# may not have run yet (or may have picked a different file). Compare by
# inode so symlink vs. real path differences don't cause false mismatches.
_sync_on_start() {
    local current last current_inode last_inode
    current=$(awww query -j 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); \
          outputs=next(iter(d.values()),[]); \
          img=outputs[0].get('displaying',{}).get('image','') if outputs else ''; \
          print(img)" 2>/dev/null || true)
    last=$(cat "$HOME/.local/share/last-matugen-wallpaper" 2>/dev/null || true)

    [ -z "$current" ] && return
    [ -z "$last" ] && { ~/.config/hypr/scripts/set-wallpaper.sh "$current"; return; }

    current_inode=$(stat -c '%d:%i' "$current" 2>/dev/null || true)
    last_inode=$(stat -c '%d:%i' "$last" 2>/dev/null || true)

    if [ -n "$current_inode" ] && [ "$current_inode" != "$last_inode" ]; then
        # Colors don't match wallpaper — sync matugen to the current wallpaper
        ~/.config/hypr/scripts/set-wallpaper.sh "$current"
    fi
}
_sync_on_start

while true; do
    now=$(date +%s)
    minute=$(date +%M)
    second=$(date +%S)

    if (( 10#$minute < 30 )); then
        # Sleep until :30
        wait=$(( (30 - 10#$minute) * 60 - 10#$second ))
    else
        # Sleep until next :00
        wait=$(( (60 - 10#$minute) * 60 - 10#$second ))
    fi

    sleep "$wait"

    if has_fullscreen_game; then
        continue
    fi

    ~/.config/hypr/scripts/set-wallpaper.sh
done
