-- ===========================================================================
-- modules/keybinds.lua — All keyboard and mouse bindings
--
-- hl.bind(keys, dispatcher, opts?)
-- opts: { locked = true }    → works even when screen is locked   (bindl)
--       { repeating = true } → fires repeatedly while held         (bindel)
--       { mouse = true }     → mouse button bind                   (bindm)
-- ===========================================================================

local mod = "SUPER"

-- ── Core apps ─────────────────────────────────────────────────────────────────
hl.bind(mod .. " + Return",        hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + E",             hl.dsp.exec_cmd("nautilus"))
hl.bind(mod .. " + SHIFT + Return",hl.dsp.exec_cmd("kitty --class floating-term"))

-- ── Scrolling layout ──────────────────────────────────────────────────────────
hl.bind(mod .. " + period",        hl.dsp.layout("colresize +conf"))   -- Cycle column width wider
hl.bind(mod .. " + comma",         hl.dsp.layout("colresize -conf"))   -- Cycle column width narrower
hl.bind(mod .. " + CTRL + right",  hl.dsp.layout("move +col"))         -- Scroll layout right
hl.bind(mod .. " + CTRL + left",   hl.dsp.layout("move -col"))         -- Scroll layout left
hl.bind(mod .. " + SHIFT + comma", hl.dsp.layout("swapcol l"))         -- Swap column left
hl.bind(mod .. " + SHIFT + period",hl.dsp.layout("swapcol r"))         -- Swap column right

-- ── Layout switching ──────────────────────────────────────────────────────────
-- Cycles the global layout: scrolling → dwindle → master (and back).
-- Pure Lua — hyprctl dispatch cyclelayout is broken in 0.55 Lua mode (IPC wraps
-- dispatch args as Lua, making "cyclelayout 1" invalid syntax).
-- hl.config updates general.layout live; all workspaces without an overriding
-- workspace_rule follow the global setting immediately.
local _LAYOUTS = {
    { name = "scrolling", label = "Scrolling", icon = "⇄"  },  -- horizontal arrow  — columns you scroll through
    { name = "dwindle",   label = "Dwindle",   icon = "󰕰"  },  -- view_grid_outline  — binary space partitioning
    { name = "master",    label = "Master",    icon = "󰕲"  },  -- view_dashboard_variant — master pane + stack
}
local _layout_i = 1   -- starts at scrolling (matches general.layout default)

local function _cycle_layout(delta)
    _layout_i = ((_layout_i - 1 + delta) % #_LAYOUTS) + 1
    local l = _LAYOUTS[_layout_i]
    hl.config({ general = { layout = l.name } })
    -- -h synchronous tag: replaces the previous layout notification instead of stacking
    hl.exec_cmd("notify-send -t 1500 -a 'Hyprland' -h 'string:x-canonical-private-synchronous:layout-cycle' '" .. l.icon .. "  Layout Changed' 'Switched to " .. l.label .. "'")
end

hl.bind(mod .. " + backslash",         function() _cycle_layout(1)  end)   -- forward
hl.bind(mod .. " + SHIFT + backslash", function() _cycle_layout(-1) end)   -- backward

-- ── Window management ─────────────────────────────────────────────────────────
hl.bind(mod .. " + Q",             hl.dsp.window.close())
hl.bind(mod .. " + F",             hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + F",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",             hl.dsp.window.pseudo())             -- Dwindle pseudotile toggle

-- Move focus — arrow keys + vim keys
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left"  }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up"    }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down"  }))
hl.bind(mod .. " + H",     hl.dsp.focus({ direction = "left"  }))
hl.bind(mod .. " + L",     hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + K",     hl.dsp.focus({ direction = "up"    }))
hl.bind(mod .. " + J",     hl.dsp.focus({ direction = "down"  }))

-- Move windows — arrow keys + vim keys
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left"  }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up"    }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down"  }))
hl.bind(mod .. " + SHIFT + H",     hl.dsp.window.move({ direction = "left"  }))
hl.bind(mod .. " + SHIFT + L",     hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + K",     hl.dsp.window.move({ direction = "up"    }))
hl.bind(mod .. " + SHIFT + J",     hl.dsp.window.move({ direction = "down"  }))

-- Resize windows with keyboard (pixel delta)
hl.bind(mod .. " + ALT + left",  hl.dsp.window.resize({ x = -40, y = 0   }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.resize({ x =  40, y = 0   }))
hl.bind(mod .. " + ALT + up",    hl.dsp.window.resize({ x = 0,   y = -40 }))
hl.bind(mod .. " + ALT + down",  hl.dsp.window.resize({ x = 0,   y =  40 }))
hl.bind(mod .. " + ALT + H",     hl.dsp.window.resize({ x = -40, y = 0   }))
hl.bind(mod .. " + ALT + L",     hl.dsp.window.resize({ x =  40, y = 0   }))
hl.bind(mod .. " + ALT + K",     hl.dsp.window.resize({ x = 0,   y = -40 }))
hl.bind(mod .. " + ALT + J",     hl.dsp.window.resize({ x = 0,   y =  40 }))

-- Move/resize with mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })   -- SUPER + LMB = move
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })   -- SUPER + RMB = resize

-- ── Workspaces ────────────────────────────────────────────────────────────────
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,              hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i,      hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + 0",          hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + SHIFT + 0",  hl.dsp.window.move({ workspace = 10 }))

-- Scroll through workspaces with mousewheel
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Special workspace (scratchpad)
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }))

-- ── Screenshots ───────────────────────────────────────────────────────────────
hl.bind("Print",                   hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))   -- Region → annotate
hl.bind(mod .. " + Print",         hl.dsp.exec_cmd("grim - | swappy -f -"))                  -- Full screen → annotate
hl.bind(mod .. " + Z",             hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))   -- Region → annotate (alt key)
hl.bind(mod .. " + X",             hl.dsp.exec_cmd("grim - | swappy -f -"))                  -- Full screen → annotate (alt key)
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))        -- Region → clipboard
hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd("grim - | wl-copy"))                      -- Full screen → clipboard

-- ── Screen recording ─────────────────────────────────────────────────────────
hl.bind(mod .. " + ALT + R",         hl.dsp.exec_cmd("~/.config/hypr/scripts/screen-record.sh area"))
hl.bind(mod .. " + ALT + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screen-record.sh fullscreen"))

-- ── Screen lock ───────────────────────────────────────────────────────────────
hl.bind(mod .. " + Escape",        hl.dsp.exec_cmd("hyprlock"))
-- Force suspend — ignores idle inhibitors (e.g. Firefox holding sleep open via YouTube)
hl.bind(mod .. " + CTRL + Escape", hl.dsp.exec_cmd("systemctl suspend -i"))

-- ── Audio — volume with OSD ────────────────────────────────────────────────
-- Output (speaker)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume-osd.sh up"),          { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume-osd.sh down"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.config/hypr/scripts/volume-osd.sh mute"),        { locked = true })
-- Input (mic) — Shift + volume knob
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume-osd.sh input-up"),   { locked = true, repeating = true })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume-osd.sh input-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("~/.config/hypr/scripts/volume-osd.sh input-mute"),  { locked = true })
-- Media keys
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),        { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),    { locked = true })
-- Audio device switching
hl.bind(mod .. " + A",         hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-switch.sh sink"))    -- Switch output
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-switch.sh source"))  -- Switch input

-- ── Brightness ────────────────────────────────────────────────────────────────
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +5%"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

-- ── Exit / reload ─────────────────────────────────────────────────────────────
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("~/.config/hypr/scripts/powermenu.sh"))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/nightlight.sh"))  -- Night light toggle
-- Restart Noctalia — clears stale workspace window counts after Wine/Steam ghost windows
hl.bind(mod .. " + CTRL + N",  hl.dsp.exec_cmd("bash -c 'kill -9 $(pgrep quickshell); sleep 0.3; noctalia-shell'"))

-- ── Gaming ────────────────────────────────────────────────────────────────────
-- Bounce to WS2 and back to break a stuck pointer-lock from a fullscreen game
hl.bind(mod .. " + CTRL + G", hl.dsp.exec_cmd(
    "hyprctl dispatch workspace 2 && sleep 0.15 && hyprctl dispatch workspace previous"
))
-- Launch Steam Big Picture Mode in a gamescope session → lands on WS 2
hl.bind(mod .. " + CTRL + B", hl.dsp.exec_cmd("steam-bpm"))

