# ===========================================================================
# modules/shells/wayle.nix — Wayle shell layer
#
# GTK4/Rust desktop shell: top bar, notification center, on-screen display,
# wallpaper management. Compositor-agnostic via wlr-layer-shell.
#
# Requires: NixOS unstable or 25.11+ (pkgs.wayle 0.3.0)
#           home-manager with services.wayle support
#
# To enable:
#   shell.wayle.enable = true;
#
# NOTE: Wayle does not provide a login screen. When switching to Wayle from
# DMS on Hyprland, add a greeter to your compositor module:
#   imports = [ ../greeters/sddm-catppuccin.nix ];
# ===========================================================================

{ config, lib, pkgs, ... }:

let cfg = config.shell.wayle; in

{
  options.shell.wayle.enable = lib.mkEnableOption "Wayle shell layer";

  config = lib.mkIf cfg.enable {

    # =========================================================================
    # Home Manager — Wayle service (injected into all users on this host)
    # =========================================================================
    home-manager.sharedModules = [

      # Wayle shell service — auto-starts with graphical session
      {
        services.wayle.enable = true;
      }

      # Clear shell-active.conf — Wayle does not need Hyprland source overrides.
      # (DMS wrote dms/*.conf sources there; Wayle manages its own layer.)
      ({ lib, ... }: {
        home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _target="$HOME/nixos-config/dotfiles/hypr/shell-active.conf"
          [ -d "$(dirname "$_target")" ] || exit 0
          : > "$_target"
        '';
      })

    ];
  };
}
