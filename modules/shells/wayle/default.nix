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

{ pkgs, lib, ... }:

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

    # Clear shell-active.conf — Wayle does not need Hyprland source overrides.
    # (DMS wrote dms/*.conf sources there; Wayle manages its own layer.)
    ({ lib, ... }: {
      home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-active.conf"
        [ -d "$(dirname "$_target")" ] || exit 0
        : > "$_target"
      '';
    })

    # Clear shell-autostart.conf — Wayle self-starts via its systemd user
    # service (WantedBy=graphical-session.target), no exec-once needed.
    ({ lib, ... }: {
      home.activation.shellAutostartConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-autostart.conf"
        [ -d "$(dirname "$_target")" ] || exit 0
        : > "$_target"
      '';
    })

  ];
}
