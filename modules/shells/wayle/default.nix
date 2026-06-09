# ===========================================================================
# modules/shells/wayle/default.nix — Wayle shell layer
#
# GTK4/Rust desktop shell: top bar, notification center, on-screen display,
# wallpaper management. Compositor-agnostic via wlr-layer-shell.
#
# pkgs.wayle is available in nixpkgs unstable (0.3.0).
# home-manager services.wayle module not yet merged — autostart is wired
# manually via a systemd user service below.
#
# Importing this module activates Wayle. No enable flag needed.
# Wayle does not provide a login screen — add greeters/sddm to your host.
#
# To switch shell: remove this import, add shells/dms or shells/noctalia.
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wayle
    awww   # Wayle's wallpaper engine backend (required for wallpaper cycling)
  ];

  # =========================================================================
  # Home Manager — Wayle autostart + Hyprland shell-active.conf
  # =========================================================================
  home-manager.sharedModules = [

    # Wayle shell — started as a systemd user service with the graphical session.
    # Replace with `services.wayle.enable = true;` once the HM module lands.
    ({ pkgs, lib, ... }: {
      systemd.user.services.wayle = {
        Unit = {
          Description = "Wayle desktop shell";
          After       = [ "graphical-session.target" ];
          PartOf      = [ "graphical-session.target" ];
        };
        Service = {
          Type      = "simple";
          ExecStart = "${pkgs.wayle}/bin/wayle shell";
          Restart   = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })

    # Write Wayle-specific Hyprland keybinds into shell-active.lua.
    # These are shell-specific — wayle CLI is only available when this module is active.
    ({ lib, ... }: {
      home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-active.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        printf '%s\n' \
          'local mod = "SUPER"' \
          'hl.bind(mod .. " + W", hl.dsp.exec_cmd("wayle wallpaper next"))' \
          'hl.bind(mod .. " + N", hl.dsp.exec_cmd("wayle notify dnd"))' \
          > "$_target"
      '';
    })

    # Clear shell-autostart.lua — Wayle self-starts via its systemd user
    # service (WantedBy=graphical-session.target), no exec-once needed.
    ({ lib, ... }: {
      home.activation.shellAutostartConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-autostart.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        : > "$_target"
      '';
    })

  ];
}
