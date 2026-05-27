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
  # Place the override in XDG_DATA_HOME (~/.local/share/applications/) so it
  # shadows the system package's entry in XDG_DATA_DIRS. xdg.desktopEntries
  # installs into the HM profile, which sits at the same XDG_DATA_DIRS
  # priority as the system package — causing launchers to show two entries.
  home.file.".local/share/applications/helium.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.5
    Name=Helium
    GenericName=Web Browser
    Icon=helium
    Exec=helium --password-store=gnome-libsecret %U
    Terminal=false
    Categories=Network;WebBrowser;
    MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
  '';
}
