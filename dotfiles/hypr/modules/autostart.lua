-- ===========================================================================
-- modules/autostart.lua — Apps and daemons that start with Hyprland
--
-- hl.on("hyprland.start", ...) = exec-once equivalent.
-- Fires once at Hyprland startup; does NOT re-run on hyprctl reload.
-- Shell-specific autostart (e.g. noctalia-shell) is in shell-autostart.lua,
-- loaded after this file by hyprland.lua.
-- ===========================================================================

hl.on("hyprland.start", function()

    -- ── Idle management ───────────────────────────────────────────────────────
    hl.exec_cmd("hypridle")

    -- ── Polkit authentication agent ───────────────────────────────────────────
    -- Needed for GUI apps to request elevated permissions (pkexec, gvfs mounts, etc.)
    hl.exec_cmd("/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1")

    -- ── Secret storage — GNOME Keyring daemon ─────────────────────────────────
    -- PAM unlocks the keyring at login, but the greetd-spawned daemon gets killed
    -- when UWSM creates its systemd session scope. Starting it here ensures the
    -- daemon lives in the UWSM-managed cgroup for the full session lifetime.
    -- Requires the login keyring to have an empty password to auto-unlock.
    hl.exec_cmd("gnome-keyring-daemon --start --daemonize --components=secrets")

    -- ── System tray daemons ───────────────────────────────────────────────────
    -- network: Noctalia bar widget handles network — no nm-applet tray needed
    -- bluetooth: Noctalia bar widget handles BT — no separate tray applet needed
    -- openrgb: systemd service runs openrgb --server headlessly; open GUI from launcher
    hl.exec_cmd("snixembed --fork")   -- XEmbed→SNI bridge: makes Wine/Proton tray icons (Battle.net) appear in Noctalia tray

    -- ── Clipboard history — wl-clipboard + cliphist ───────────────────────────
    -- Watches clipboard for text and images; SUPER+V opens history picker.
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- ── Night light — auto warm colors at sunset (8 PM) ───────────────────────
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/nightlight.sh on")

    -- ── Host-specific overrides ───────────────────────────────────────────────
    -- Sets per-display opacity (e.g. OLED needs lower opacity than LCD)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/host-overrides.sh")

    -- ── Auto column width ─────────────────────────────────────────────────────
    -- Scrolling layout: 67% for 1 window, 50% for 2+
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/col-width-auto.sh")

    -- ── Game workspace ────────────────────────────────────────────────────────
    -- Move Proton/native-Wayland games to WS 2 after Steam places them.
    -- Windowrules fire too early (before Steam's set_fullscreen request); this
    -- script listens to openwindow events and moves proton-game windows after settle.
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/game-workspace.sh")

end)
