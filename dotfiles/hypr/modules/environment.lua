-- ===========================================================================
-- modules/environment.lua — Environment variables
--
-- Set inside the Hyprland session so every app launched from Hyprland
-- inherits them. Cursor, toolkit backends, and session identity live here.
-- ===========================================================================

-- Cursor — BreezeX-Light (XCursor format; no native hyprcursor package)
-- home.pointerCursor in themes/default.nix installs the theme and sets
-- XCURSOR_THEME in the systemd user environment. These env vars ensure
-- Hyprland + X11 apps also pick it up. HYPRCURSOR_* intentionally omitted
-- (Hyprland falls back to XCursor when no hyprcursor theme is set).
hl.env("XCURSOR_THEME", "BreezeX-Light")
hl.env("XCURSOR_SIZE",  "24")

-- Session identity — tells apps they're running under Hyprland/Wayland
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE",    "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- GTK — prefer Wayland backend, fall back to X11 for anything that needs it
hl.env("GDK_BACKEND", "wayland,x11,*")

-- Qt — run natively on Wayland; follow GTK dark theme
hl.env("QT_QPA_PLATFORM",                 "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME",            "qt6ct")
hl.env("QT_STYLE_OVERRIDE",               "Adwaita-Dark")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Firefox / Electron — force native Wayland renderer
hl.env("MOZ_ENABLE_WAYLAND",           "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Java apps (e.g. Minecraft launchers) — fix blank window bug on tiling WMs
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
