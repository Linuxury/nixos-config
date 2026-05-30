# ===========================================================================
# modules/hardware/openrgb/default.nix — OpenRGB RGB lighting control
#
# The NixOS module already creates a systemd service that runs openrgb
# --server on boot (wantedBy multi-user.target). This module centralises
# the common AMD config across all three desktop hosts.
#
# To persist RGB colors across reboots, save a profile in the OpenRGB GUI
# (Profile → Save Profile), then set:
#
#   services.hardware.openrgb.startupProfile = "my-profile";
#
# The file must be in /var/lib/OpenRGB/<name>.orp
# ===========================================================================

{ ... }:

{
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
    startupProfile = "main";
  };
}
