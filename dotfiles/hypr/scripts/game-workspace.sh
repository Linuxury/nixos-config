#!/usr/bin/env bash
# game-workspace.sh — Move games to WS 2 after launchers place them.
#
# Why a script instead of a windowrule:
#   Game launchers (Steam, Prism) call set_fullscreen or activate the game window
#   after Hyprland evaluates windowrules, overriding workspace placement. This script
#   listens to openwindow events and moves games after they fully settle.
#
# Matches:
#   - xdgTag "proton-game"            — Steam/Proton native Wayland games
#   - class "^Minecraft"              — Minecraft via Prism Launcher (XWayland)
#   - class "steam_app_0", title != "" — Battle.net games (Diablo, etc.) — tray icon has empty title

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

is_game() {
    local addr="$1"
    python3 -c "
import json, sys, subprocess
data = json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))
for w in data:
    if w['address'] == '0x$addr':
        xdg_tag = w.get('xdgTag', '')
        cls = w.get('class', '')
        title = w.get('title', '')
        if xdg_tag == 'proton-game':
            print('match')
        elif cls.startswith('Minecraft'):
            print('match')
        elif cls == 'steam_app_0' and title:
            print('match')
        break
" 2>/dev/null
}

handle() {
    local event="$1"
    [[ "$event" != openwindow* ]] && return

    # openwindow>>address,workspacename,class,title
    local addr="${event#openwindow>>}"
    addr="${addr%%,*}"

    sleep 1

    if [[ "$(is_game "$addr")" == "match" ]]; then
        hyprctl dispatch movetoworkspacesilent "2,address:0x$addr"
    fi
}

socat -U - "UNIX-CONNECT:$SOCKET" | while IFS= read -r line; do
    handle "$line" &
done
