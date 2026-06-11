-- ===========================================================================
-- modules/windowrules.lua — Per-app window behavior
--
-- Each rule is a table with:
--   name    = unique identifier (optional but good for debugging)
--   match   = { class, title, xwayland, float, fullscreen, pin, … }
--   effects = all other fields (workspace, float, size, move, opacity, …)
-- ===========================================================================

-- ── Global ───────────────────────────────────────────────────────────────────
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- ── Workspace assignments ─────────────────────────────────────────────────────
-- WS 1: Regular apps (default — no rule needed)
-- WS 2: Games / fullscreen
-- WS 3: Steam

hl.window_rule({ match = { class = "^steam$"                               }, workspace = "3 silent" })
hl.window_rule({ match = { class = "org.prismlauncher.PrismLauncher"       }, workspace = "3 silent" })

-- Games → WS 2
-- Note: Proton/Steam games are handled by game-workspace.sh (event-based, runs after
-- Steam's set_fullscreen request — windowrules fire too early for native Wayland games).
hl.window_rule({ match = { class = "gamescope"         }, workspace = "2 silent" })
hl.window_rule({ match = { class = "lutris"            }, workspace = "2 silent" })
hl.window_rule({ match = { class = "heroic"            }, workspace = "2 silent" })
hl.window_rule({ match = { class = "minecraft-launcher"}, workspace = "2 silent" })
hl.window_rule({ match = { class = "^Minecraft"        }, workspace = "2 silent" })
hl.window_rule({ match = { class = "HytaleClient"      }, workspace = "2 silent" })

-- Fullscreen apps → WS 2
-- NOTE: This rule only fires at window creation time, so it only catches windows
-- that open already-fullscreen. Most games go fullscreen after opening — those are
-- handled by game-workspace.sh which listens to fullscreen socket2 events instead.
hl.window_rule({ match = { fullscreen = true }, workspace = "2 silent" })

-- ── Floating windows ──────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "pavucontrol"       }, float = true })
hl.window_rule({ match = { class = "blueman-manager"   }, float = true })
hl.window_rule({ match = { class = "nm-connection-editor" }, float = true })
hl.window_rule({ match = { class = "nwg-look"          }, float = true })
hl.window_rule({ match = { class = "qt6ct"             }, float = true })
hl.window_rule({ match = { class = "gnome-disks"       }, float = true })
hl.window_rule({ match = { title = "Open File"         }, float = true })
hl.window_rule({ match = { title = "Save File"         }, float = true })
hl.window_rule({ match = { title = "File Upload"       }, float = true })

-- Floating kitty — launched with SUPER+SHIFT+Return as a quick terminal
hl.window_rule({
    match    = { class = "floating-term" },
    float    = true,
    size     = "(monitor_w*0.5) (monitor_h*0.6)",
    center   = true,
})

-- ── Transparency ──────────────────────────────────────────────────────────────
-- Kitty transparency — Hyprland controls opacity; Kitty's own settings disabled
-- 0.75 active, 0.6 inactive — override prevents product multiplication
hl.window_rule({
    match   = { class = "kitty" },
    opacity = "0.75 override 0.6 override",
})

-- Nautilus — file manager transparency
hl.window_rule({
    match   = { class = "org.gnome.Nautilus" },
    opacity = "0.85 override 0.75 override",
})

-- ── Launcher (wofi) ───────────────────────────────────────────────────────────
-- wofi window rules injected by modules/components/launcher/

-- Powermenu variants
hl.window_rule({ match = { class = "powermenu"       }, rounding = 10 })
hl.window_rule({ match = { class = "powermenu"       }, float    = true })
hl.window_rule({ match = { class = "powermenu"       }, center   = true })
hl.window_rule({ match = { class = "powermenu-small" }, rounding = 10 })
hl.window_rule({ match = { class = "powermenu-small" }, float    = true })
hl.window_rule({ match = { class = "powermenu-small" }, center   = true })

-- ── Picture-in-picture ────────────────────────────────────────────────────────
hl.window_rule({ match = { title = "Picture-in-Picture" }, float             = true })
hl.window_rule({ match = { title = "Picture-in-Picture" }, pin               = true })
hl.window_rule({ match = { title = "Picture-in-Picture" }, keep_aspect_ratio = true })

-- ── Wine/Proton — hide Battle.net's native XEmbed tray icon window ────────────
-- We use a custom waybar module instead. Matches the small floating window
-- with empty title (160x20 tray icon). Shrunk to 1x1 and pushed off-screen.
hl.window_rule({ match = { class = "steam_app_0", title = "^$" }, float = true           })
hl.window_rule({ match = { class = "steam_app_0", title = "^$" }, size  = "1 1"          })
hl.window_rule({ match = { class = "steam_app_0", title = "^$" }, move  = "0 1439"       })

-- ── XWayland ─────────────────────────────────────────────────────────────────
-- Disable rounding on X11 windows (looks bad)
hl.window_rule({ match = { xwayland = true }, rounding = 0 })
-- Battle.net — restore rounding (overrides the XWayland rule above)
hl.window_rule({ match = { class = "steam_app_0" }, rounding = 10 })

-- ── Idle inhibit ─────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = ".*" },   idle_inhibit = "fullscreen" })
hl.window_rule({ match = { class = "mpv" },  idle_inhibit = "focus"      })

-- ── Layer rules ──────────────────────────────────────────────────────────────
-- swaync layer rules injected by modules/components/notifications/
