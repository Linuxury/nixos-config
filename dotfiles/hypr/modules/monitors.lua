-- ===========================================================================
-- modules/monitors.lua — Monitor layout
--
-- hl.monitor() fields: output (required), mode, position, scale (string),
--   transform, bitdepth, vrr (-1=auto, 0=off, 1=on, 2=fullscreen-only, 3=always)
--
-- The catch-all rule (output = "") auto-detects preferred resolution and
-- refresh rate for any connected display. Works on both ThinkPad (1920x1200)
-- and Ryzen5900x (3440x1440) without any changes.
-- The catch-all must always be last — Hyprland matches top to bottom.
-- ===========================================================================

-- Ryzen5900x — LG 34" ultrawide (3440x1440, 240Hz, VRR)
-- bitdepth 10 = 10-bit color
-- HDR enabled per-game via PROTON_ENABLE_HDR=1 %command%
-- VRR is managed by DMS when active; static config here for non-DMS sessions.
hl.monitor({
    output   = "DP-3",
    mode     = "3440x1440@240",
    position = "0x0",
    scale    = "1",
    bitdepth = 10,
    vrr      = 2,   -- fullscreen-only VRR (avoids flickering on the desktop)
})

-- Catch-all — ThinkPad built-in display and any unknown outputs
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
