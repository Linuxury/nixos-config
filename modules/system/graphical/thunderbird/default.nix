# ===========================================================================
# modules/system/graphical/thunderbird/default.nix — Thunderbird email client
#
# Imported by: hosts that need an email client (currently linuxury hosts)
#
# Sets Thunderbird as the default handler for mailto links, .eml files,
# calendar invites, and contact cards via home-manager.sharedModules so
# the MIME defaults only exist when the package is actually installed.
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.thunderbird ];

  home-manager.sharedModules = [{
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/mailto" = "thunderbird.desktop";  # mailto: links
      "message/rfc822"          = "thunderbird.desktop";  # .eml files
      "text/calendar"           = "thunderbird.desktop";  # .ics calendar invites
      "text/x-vcard"            = "thunderbird.desktop";  # .vcf contact cards
    };
  }];
}
