# ===========================================================================
# modules/base/firefox.nix — System-wide Firefox configuration
#
# Installs Firefox with forced policies that apply to ALL users.
# Nobody can remove uBlock Origin or the custom filters — they are
# locked in place by the system policy.
#
# Import this module in every desktop/laptop host config.
# Servers don't need it.
# ===========================================================================

{ config, pkgs, ... }:

let
  # =========================================================================
  # Custom uBlock Origin filter list
  #
  # Defined as a let binding so the same string is used in both:
  #   1. environment.etc — places the file on disk at /etc/ublock-custom-filters.txt
  #   2. programs.firefox policies — pushes it directly to uBlock Origin
  #
  # Do NOT use builtins.readFile /etc/ublock-custom-filters.txt here —
  # that path doesn't exist at Nix evaluation time on a fresh build.
  # =========================================================================
  uBlockCustomFilters = ''
    ! Title: Hide YouTube Shorts
    ! Description: Hide all traces of YouTube shorts videos on YouTube
    ! Version: 1.8.0
    ! Last modified: 2023-01-08 20:02
    ! Expires: 2 weeks (update frequency)
    ! Homepage: https://github.com/gijsdev/ublock-hide-yt-shorts
    ! License: https://github.com/gijsdev/ublock-hide-yt-shorts/blob/master/LICENSE.md
    ! Hide all videos containing the phrase "#shorts"
    youtube.com##ytd-grid-video-renderer:has(#video-title:has-text(#shorts))
    youtube.com##ytd-grid-video-renderer:has(#video-title:has-text(#Shorts))
    youtube.com##ytd-grid-video-renderer:has(#video-title:has-text(#short))
    youtube.com##ytd-grid-video-renderer:has(#video-title:has-text(#Short))
    ! Hide all videos with the shorts indicator on the thumbnail
    youtube.com##ytd-grid-video-renderer:has([overlay-style="SHORTS"])
    youtube.com##ytd-rich-item-renderer:has([overlay-style="SHORTS"])
    youtube.com##ytd-video-renderer:has([overlay-style="SHORTS"])
    youtube.com##ytd-item-section-renderer.ytd-section-list-renderer[page-subtype="subscriptions"]:has(ytd-video-renderer:has([overlay-style="SHORTS"]))
    ! Hide shorts button in sidebar
    youtube.com##ytd-guide-entry-renderer:has-text(Shorts)
    youtube.com##ytd-mini-guide-entry-renderer:has-text(Shorts)
    ! Hide shorts section on homepage
    youtube.com##ytd-rich-section-renderer:has(#rich-shelf-header:has-text(Shorts))
    youtube.com##ytd-reel-shelf-renderer:has(.ytd-reel-shelf-renderer:has-text(Shorts))
    ! Hide shorts tab on channel pages
    ! Old style
    youtube.com##tp-yt-paper-tab:has(.tp-yt-paper-tab:has-text(Shorts))
    ! New style (2023-10)
    youtube.com##yt-tab-shape:has-text(/^Shorts$/)
    ! Hide shorts in video descriptions
    youtube.com##ytd-reel-shelf-renderer.ytd-structured-description-content-renderer:has-text("Shorts remixing this video")
    ! Remove empty spaces in grid
    youtube.com##ytd-rich-grid-row,#contents.ytd-rich-grid-row:style(display: contents !important)
    !!! MOBILE !!!
    ! Hide all videos in home feed containing the phrase "#shorts"
    m.youtube.com##ytm-rich-item-renderer:has(#video-title:has-text(#shorts))
    m.youtube.com##ytm-rich-item-renderer:has(#video-title:has-text(#Shorts))
    m.youtube.com##ytm-rich-item-renderer:has(#video-title:has-text(#short))
    m.youtube.com##ytm-rich-item-renderer:has(#video-title:has-text(#Short))
    ! Hide all videos in subscription feed containing the phrase "#shorts"
    m.youtube.com##ytm-item-section-renderer:has(#video-title:has-text(#shorts))
    m.youtube.com##ytm-item-section-renderer:has(#video-title:has-text(#Shorts))
    m.youtube.com##ytm-item-section-renderer:has(#video-title:has-text(#short))
    m.youtube.com##ytm-item-section-renderer:has(#video-title:has-text(#Short))
    ! Hide shorts button in the bottom navigation bar
    m.youtube.com##ytm-pivot-bar-item-renderer:has(.pivot-shorts)
    ! Hide all videos with the shorts indicator on the thumbnail
    m.youtube.com##ytm-video-with-context-renderer:has([data-style="SHORTS"])
    ! Hide shorts sections
    m.youtube.com##ytm-rich-section-renderer:has(ytm-reel-shelf-renderer:has(.reel-shelf-title-wrapper:has-text(Shorts)))
    m.youtube.com##ytm-reel-shelf-renderer.item:has(.reel-shelf-title-wrapper:has-text(Shorts))
    ! Hide shorts tab on channel pages
    m.youtube.com##.single-column-browse-results-tabs>a:has-text(Shorts)
  '';

in

{
  # =========================================================================
  # Place the filter file on disk for reference/debugging
  # =========================================================================
  environment.etc."ublock-custom-filters.txt" = {
    text = uBlockCustomFilters;
    mode = "0644";
  };

  # =========================================================================
  # Firefox with enforced policies
  #
  # programs.firefox.policies applies settings via Firefox's enterprise
  # policy system. These cannot be overridden by users in the browser UI.
  # =========================================================================
  programs.firefox = {
    enable = true;

    # -----------------------------------------------------------------------
    # Preferences — browser settings locked for all users
    # -----------------------------------------------------------------------
    preferences = {
      # Disable sponsored content and pocket
      "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
      "browser.newtabpage.activity-stream.showSponsored"             = false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites"     = false;

      # Disable telemetry
      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "toolkit.telemetry.enabled" = false;
      "toolkit.telemetry.unified" = false;

      # Enable userChrome.css customization (useful for later)
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    };

    policies = {
      # -----------------------------------------------------------------------
      # Disable Firefox features we don't want
      # -----------------------------------------------------------------------
      DisableTelemetry          = true;
      DisableFirefoxStudies     = true;
      DisablePocket             = true;        # Remove Pocket integration
      DisableFirefoxAccounts    = false;       # Keep FF accounts — syncing is useful
      DontCheckDefaultBrowser   = true;
      DisableFormHistory        = false;       # Keep form history — convenience

      # -----------------------------------------------------------------------
      # Force install extensions + uBlock Origin configuration
      #
      # Extensions listed here are installed automatically for ALL users
      # and cannot be removed by the user.
      # The "3rdparty" key pushes default settings to extensions.
      # -----------------------------------------------------------------------
      ExtensionSettings = {
        # uBlock Origin — forced install, cannot be removed
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };

        # Proton Pass — forced install for password management
        "{d3197588-0b88-4f1b-868f-477562e3d367}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/proton-pass/latest.xpi";
        };

        # Push default configuration to uBlock Origin for all users.
        # Enables our custom Shorts filter alongside standard filter lists.
        "3rdparty" = {
          Extensions = {
            "uBlock0@raymondhill.net" = {
              adminSettings = {
                userSettings = {
                  uiTheme               = "dark";
                  showIconBadge         = true;
                  alwaysDetachLogger    = false;
                };
                selectedFilterLists = [
                  "ublock-filters"      # uBlock Origin built-in filters
                  "ublock-badware"      # Malware protection
                  "ublock-privacy"      # Privacy protection
                  "ublock-unbreak"      # Fix broken sites after filtering
                  "easylist"            # Standard ad blocking
                  "easyprivacy"         # Tracking protection
                  "urlhaus-1"           # Malicious URL blocking
                ];
                userFilters = uBlockCustomFilters;
              };
            };
          };
        };
      };

      # -----------------------------------------------------------------------
      # Search engine — set DuckDuckGo as default
      # -----------------------------------------------------------------------
      SearchEngines = {
        Default = "DuckDuckGo";
        PreventInstalls = false;
      };

      # -----------------------------------------------------------------------
      # Homepage
      # -----------------------------------------------------------------------
      Homepage = {
        URL = "about:home";
        Locked = false; # Users can change their own homepage
      };

      # -----------------------------------------------------------------------
      # Security settings
      # -----------------------------------------------------------------------
      HttpsOnlyMode         = "enabled";  # Force HTTPS everywhere
      EnableTrackingProtection = {
        Value            = true;
        Locked           = true;          # Cannot be disabled by users
        Cryptomining     = true;
        Fingerprinting   = true;
      };

      # -----------------------------------------------------------------------
      # Cookies and privacy
      # -----------------------------------------------------------------------
      Cookies = {
        Behavior         = "reject-tracker-and-partition-foreign";
        BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
      };
    };
  };
}
