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
  #
  # glib.bin (gdbus) — the plugin's entire DBus layer shells out to the bare
  # `gdbus` command for every call to kdeconnectd. glib itself is always
  # present as a library dependency of other packages, but its `bin` output
  # (gdbus/gio/gsettings) isn't pulled onto PATH unless installed explicitly
  # — without it every gdbus call silently fails as "command not found" and
  # the plugin sees no devices, even though kdeconnectd is paired and working.
  environment.systemPackages = [ pkgs.sshfs pkgs.glib.bin ];
}
