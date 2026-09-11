# ===========================================================================
# modules/services/kdeconnect/default.nix — KDE Connect
#
# Phone/desktop integration — share clipboard, notifications, files, and
# more between your phone and desktop. Works on any DE despite the name
# (COSMIC, Hyprland, KDE, GNOME, etc.).
#
# The NixOS module opens the required firewall ports (1714-1764) automatically.
#
# Enable per host by importing this module:
#   ../../modules/services/kdeconnect/default.nix
# ===========================================================================

{ pkgs, ... }:

{
  programs.kdeconnect.enable = true;

  # sshfs — declared dependency of Noctalia's community phone-connect plugin
  # (browsing/mounting the phone's filesystem over KDE Connect's sftp backend).
  environment.systemPackages = [ pkgs.sshfs ];
}
