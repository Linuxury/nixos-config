-- Shell-specific exec-once.
-- Written at HM activation by the active shell module.
-- Noctalia writes this; DMS and Wayle leave it empty (they self-start via systemd).

hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia-shell")
end)
