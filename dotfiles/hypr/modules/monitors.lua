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
-- cm = "srgb" pairs with render:cm_auto_hdr (appearance.lua) to auto-enable
-- HDR only for fullscreen HDR-capable clients and correctly revert on exit —
-- "wide"/"auto" have an open upstream bug where they don't revert (hyprwm/Hyprland#12971).
-- Per-compat-layer Proton HDR flags (now mostly obsolete) are documented in
-- modules/gaming/default.nix.
hl.monitor({
    output   = "DP-3",
    mode     = "3440x1440@240",
    position = "0x0",
    scale    = "1",
    bitdepth = 10,
    cm       = "srgb",
    vrr      = 2,   -- fullscreen-only VRR (avoids flickering on the desktop)
})

-- Catch-all — ThinkPad built-in display and any unknown outputs
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
