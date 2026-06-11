#!/usr/bin/env bash
# game-workspace.sh — Move games/fullscreen windows to WS 2 after launchers place them.
#
# Why a script instead of a windowrule:
#   Game launchers (Steam, Prism) call set_fullscreen after Hyprland evaluates
#   windowrules, overriding workspace placement. The fullscreen=true windowrule
#   fires at window creation (too early — the window isn't fullscreen yet).
#   This script handles both cases:
#
#   openwindow — known game classes that settle before going fullscreen
#     - xdgTag "proton-game"              — Steam/Proton native Wayland games
#     - class "^Minecraft"                — Minecraft via Prism Launcher (XWayland)
#     - class "steam_app_0", title != ""  — Battle.net games; tray icon has empty title
#
#   fullscreen — any window entering actual fullscreen (catches everything else)
#     Hyprland 0.41+: fullscreen>>WINDOWADDRESS,INTERNALSTATE[,CLIENTSTATE]
#       state 0=none, 1=maximized, 2=fullscreen
#     Older: fullscreen>>1 (1=entered, 0=left)

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

is_game() {
    local addr="$1"
    python3 -c "
import json, subprocess
data = json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))
for w in data:
    if w['address'] == '0x$addr':
        xdg_tag = w.get('xdgTag', '')
        cls     = w.get('class', '')
        title   = w.get('title', '')
        if xdg_tag == 'proton-game':
            print('match')
        elif cls.startswith('Minecraft'):
            print('match')
        elif cls == 'steam_app_0' and title:
            print('match')
        break
" 2>/dev/null
}

move_to_ws2() {
    local addr="$1"
    python3 -c "
import json, subprocess
data = json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))
for w in data:
    if w['address'] == '0x$addr':
        ws = w.get('workspace', {}).get('id', 0)
        if ws != 2:
            subprocess.run(['hyprctl', 'dispatch', 'movetoworkspacesilent', '2,address:0x$addr'])
        break
" 2>/dev/null
}

handle() {
    local event="$1"

    if [[ "$event" == openwindow* ]]; then
        # openwindow>>address,workspacename,class,title
        local addr="${event#openwindow>>}"
        addr="${addr%%,*}"
        sleep 1
        if [[ "$(is_game "$addr")" == "match" ]]; then
            hyprctl dispatch movetoworkspacesilent "2,address:0x$addr"
        fi

    elif [[ "$event" == fullscreen* ]]; then
        local payload="${event#fullscreen>>}"
        local addr state

        if [[ "$payload" == *","* ]]; then
            # 0.41+ format: WINDOWADDRESS,INTERNALSTATE[,CLIENTSTATE]
            addr="${payload%%,*}"
            addr="${addr#0x}"   # normalize — strip 0x if present in event
            local rest="${payload#*,}"
            state="${rest%%,*}"
            # Only act on actual fullscreen (2), not maximized (1) or restored (0)
            [[ "$state" == "2" ]] || return
        else
            # Older format: 1=entered fullscreen, 0=left
            [[ "$payload" == "1" ]] || return
            addr=$(hyprctl activewindow -j 2>/dev/null \
                   | python3 -c "import json,sys; print(json.load(sys.stdin).get('address','').lstrip('0x'))" 2>/dev/null)
            [[ -z "$addr" ]] && return
        fi

        sleep 0.3
        move_to_ws2 "$addr"
    fi
}

socat -U - "UNIX-CONNECT:$SOCKET" | while IFS= read -r line; do
    handle "$line" &
done
