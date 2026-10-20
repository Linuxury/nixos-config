# ===========================================================================
# modules/users/uids.nix — fixed UID per person, identical on every host
#
# Without pins NixOS hands out UIDs alphabetically per host (alex < babylinux
# < linuxury), so the same person got 1000 on one machine and 1002 on another.
# Applied by modules/users/uid-pin; also read by the installer.
# ===========================================================================
{
  linuxury  = 1000;
  babylinux = 1001;
  alex      = 1002;
}
