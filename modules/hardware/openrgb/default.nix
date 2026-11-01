# ===========================================================================
# modules/hardware/openrgb/default.nix — OpenRGB RGB lighting control
#
# Option-gated module — imported for ALL hosts in flake.nix (mkHost).
# Dormant until a host enables it:
#
#   hardware.openrgb.enable = true;
#
# Enabling pulls in everything at once: the openrgb package, the udev
# rules (device access for non-root users), and the `openrgb --server`
# systemd service on boot.
#
# Optional: set `hardware.openrgb.profile` to load a saved profile
# (/var/lib/OpenRGB/profiles/<name>.json) on boot. Leave it null when something
# else (Noctalia led-sync) owns the colours — a startup profile is applied after
# device detection and overrides whatever that pushed first.
# ===========================================================================

{ config, lib, ... }:

let
  cfg = config.hardware.openrgb;
in
{
  # ==============================================================
  # Options
  # ==============================================================
  options.hardware.openrgb = {
    enable = lib.mkEnableOption "OpenRGB with udev rules and server daemon";

    motherboard = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" ];
      default = "amd";
      description = "Motherboard platform — loads the matching SMBus kernel module.";
    };

    profile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Profile loaded by the server on boot; null loads none.";
    };
  };

  # ==============================================================
  # Implementation — only materialises when enable = true
  # ==============================================================
  config = lib.mkIf cfg.enable {
    services.hardware.openrgb = {
      enable = true;
      motherboard = cfg.motherboard;
      startupProfile = cfg.profile;
    };
  };
}
