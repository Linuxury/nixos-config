# ===========================================================================
# modules/home/helium.nix — Helium browser keyring integration
#
# Helium is a Chromium-based browser. Without an explicit flag, Chromium
# picks a password-store backend that may not connect to the already-unlocked
# GNOME Keyring — causing it (and extensions like Proton Pass) to lose their
# stored sessions and re-prompt for credentials on every launch.
#
# This module overrides Helium's desktop entry to pass
# --password-store=gnome-libsecret, binding Chromium directly to the system
# keyring that PAM unlocks at login (see mangowc.nix / cosmic.nix / hyprland.nix).
#
# Imported by all graphical users alongside the package in graphical-base.nix.
# ===========================================================================

{ ... }:

{
  xdg.desktopEntries.helium = {
    name = "Helium";
    genericName = "Web Browser";
    exec = "helium --password-store=gnome-libsecret %U";
    icon = "helium";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };
}
