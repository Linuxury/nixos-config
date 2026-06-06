# ===========================================================================
# modules/hardware/peripherals/lemokey-keychron/default.nix — WebHID access
#
# The Lemokey and Keychron web launchers use the WebHID API to configure
# keyboards and mice directly from the browser. By default /dev/hidraw*
# nodes are root-only. TAG+="uaccess" tells systemd-logind to grant the
# active logged-in user a session-scoped ACL — no MODE=0666 or static
# group needed.
#
# VID 362d = Lemokey  (Hall Effect keyboards — P1 HE, etc.)
# VID 3434 = Keychron (QMK keyboards + M-series mice)
#
# Enable per host by importing this module:
#   ../../modules/hardware/peripherals/lemokey-keychron/default.nix
# ===========================================================================

{ ... }:

{
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="362d", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"
  '';
}
