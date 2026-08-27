# ===========================================================================
# modules/system/graphical/thunderbird/default.nix — Thunderbird email client
#
# Imported by: hosts that need an email client (currently linuxury hosts)
#
# Sets Thunderbird as the default handler for mailto links, .eml files,
# calendar invites, and contact cards via home-manager.sharedModules so
# the MIME defaults only exist when the package is actually installed.
# ===========================================================================

{ ... }:

{
  programs.thunderbird = {
    enable = true;

    # Force-installed extensions — same pywalfox pattern as Firefox
    # (dotfiles/firefox/policies.json). Same extension ID on both stores
    # (confirmed via each store's actual .xpi manifest), so the native
    # messaging host manifest's allowed_extensions doesn't need a second
    # entry — just a copy of the manifest itself in Thunderbird's own
    # native-messaging-hosts directory (~/.thunderbird/, separate from
    # Firefox's ~/.mozilla/), installed per-user same as Firefox's.
    policies.ExtensionSettings = {
      "pywalfox@frewacom.org" = {
        install_url = "https://addons.thunderbird.net/thunderbird/downloads/latest/pywalfox/latest.xpi";
        installation_mode = "force_installed";
      };
    };
  };

  home-manager.sharedModules = [{
    xdg.mimeApps.defaultApplications = {
      # Email
      "x-scheme-handler/mailto" = "thunderbird.desktop";  # mailto: links
      "message/rfc822"          = "thunderbird.desktop";  # .eml files

      # Calendar
      "text/calendar"            = "thunderbird.desktop";  # .ics files
      "x-scheme-handler/webcal"  = "thunderbird.desktop";  # webcal:// subscribe links
      "x-scheme-handler/webcals" = "thunderbird.desktop";  # webcals:// (TLS)

      # Contacts
      "text/x-vcard"             = "thunderbird.desktop";  # .vcf contact cards
      "text/directory"           = "thunderbird.desktop";  # vCard directory format

      # Feeds — Thunderbird checks for these; no dedicated reader installed
      "application/rss+xml"      = "thunderbird.desktop";
      "application/atom+xml"     = "thunderbird.desktop";
      "x-scheme-handler/feed"    = "thunderbird.desktop";
      "x-scheme-handler/feeds"   = "thunderbird.desktop";

      # Newsgroups
      "x-scheme-handler/news"    = "thunderbird.desktop";
      "x-scheme-handler/snews"   = "thunderbird.desktop";
      "x-scheme-handler/nntp"    = "thunderbird.desktop";

      # Thunderbird internal links (net.thunderbird://)
      "x-scheme-handler/net.thunderbird" = "thunderbird.desktop";
    };
  }];
}
