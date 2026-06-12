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
# To persist RGB colors across reboots, save a profile in the OpenRGB GUI
# (Profile → Save Profile) named after `hardware.openrgb.profile`.
# The file must end up in /var/lib/OpenRGB/<name>.orp
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
      type = lib.types.str;
      default = "main";
      description = "Profile (/var/lib/OpenRGB/<name>.orp) loaded by the server on boot.";
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
