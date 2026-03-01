# ===========================================================================
# hosts/Radxa-X4/default.nix — Radxa X4
#
# Owner: managed by linuxury
# Hardware: Intel N100, Intel UHD integrated graphics
# Type: Headless server — no DE, no display manager
# Role: Home server — services TBD
#
# Enabled modules:
#   - Intel drivers
#   - base/common.nix
#   - FreshRSS (port 8080)
#
# No desktop environment, no Home Manager, no gaming, no development.
# Managed remotely via SSH by linuxury.
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

let
  # -------------------------------------------------------------------------
  # FreshRSS extension helpers
  # -------------------------------------------------------------------------
  buildExt = pkgs.freshrss-extensions.buildFreshRssExtension;

  # Official FreshRSS/Extensions repo — same commit nixpkgs pins (2025-12-26).
  # youtube, title-wrap, unsafe-auto-login, reading-time are already exposed
  # directly as pkgs.freshrss-extensions.{name}. The others below are built
  # from the same pre-fetched src to avoid a second download.
  officialSrc = pkgs.fetchFromGitHub {
    owner = "FreshRSS";
    repo  = "Extensions";
    rev   = "42c32bfd9af2d816933cf310e24d25888a8e167d";
    hash  = "sha256-El488QK3xWQM01GsuyBizud6VghXsRDqiOblnMfjVxE=";
  };

  # Collection repos — fetched once, split into multiple extensions each.
  autoRefreshSrc = pkgs.fetchFromGitHub {
    owner = "Eisa01";
    repo  = "FreshRSS---Auto-Refresh-Extension";
    rev   = "ec03af34909cb52b314da1f97d5d80c3ce237c20";
    hash  = "sha256-z2Q6fQ0drzd945LVu2KAFqqNHonxfjb3l4L17Gs5ec8=";
  };

  kapdapSrc = pkgs.fetchFromGitHub {
    owner = "kapdap";
    repo  = "freshrss-extensions";
    rev   = "a44a25a6b8c7f298ac05b8db323bdea931e6e530";
    hash  = "sha256-uWZi0sHdfDENJqjqTz5yoDZp3ViZahYI2OUgajdx4MQ=";
  };

  devonSrc = pkgs.fetchFromGitHub {
    owner = "DevonHess";
    repo  = "FreshRSS-Extensions";
    rev   = "299c1febc279be77fa217ff5c2965a620903b974";
    hash  = "sha256-++kgbrGJohKeOeLjcy7YV3QdCf9GyZDtbntlFmmIC5k=";
  };

  cntoolsSrc = pkgs.fetchFromGitHub {
    owner = "cn-tools";
    repo  = "cntools_FreshRssExtensions";
    rev   = "ae40a34e260e0609e49d1a338e42284383e9703b";
    hash  = "sha256-4103QhVRWVe4HYbReX/qPA4KwtHZ5AsAxwpX9hQMwCw=";
  };

in
{
  imports = [
    ../../modules/base/common.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/base/auto-update.nix
    ../../modules/base/server-shell.nix
    ../../modules/hardware/drivers.nix
    ../../modules/services/samba.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Radxa-X4";

  # =========================================================================
  # GPU driver selection
  # Intel UHD integrated graphics (Alder Lake N)
  # =========================================================================
  hardware.gpu = "intel";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on server
  # =========================================================================
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd:1" "noatime" ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd:1" "noatime" ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd:1" "noatime" ];
    };

    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd:1" "noatime" ];
    };

    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@cache" "compress=zstd:1" "noatime" ];
    };

    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd:1" "noatime" ];
    };

    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@swap" "noatime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  # =========================================================================
  # Swap
  # =========================================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # =========================================================================
  # Kernel
  #
  # The Intel N100 is a newer Alder Lake N chip. Using latest stable
  # ensures we have the best driver support for this relatively recent SoC.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Intel N100 specific settings
  #
  # The N100 is an efficiency-focused chip designed for low power
  # operation. These settings help it run optimally as a always-on
  # server without wasting power.
  # =========================================================================
  boot.kernelParams = [
    "intel_pstate=active"  # Use Intel's own CPU frequency scaling driver
                           # Better performance/power balance than generic
  ];

  # =========================================================================
  # Intel microcode and power management
  # =========================================================================
  hardware.cpu.intel.updateMicrocode = true;

  # powertop auto-tune — applies Intel's recommended power saving settings
  # automatically at boot. Great for an always-on low power server.
  powerManagement.powertop.enable = true;

  # =========================================================================
  # GPIO — Radxa X4 specific
  #
  # The Radxa X4 has a 40-pin GPIO header with an RP2040 co-processor.
  # These packages let you interact with GPIO pins if needed for
  # home automation or hardware projects later.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Monitoring (same as MinisForum)
    iotop
    nethogs
    ncdu
    smartmontools
    rsync
    rclone
    tmux
    lsof
    strace

    # GPIO tools for the 40-pin header
    libgpiod        # GPIO control from command line
                    # Usage: gpioget, gpioset commands
    i2c-tools       # I2C bus utilities for sensors and peripherals
    minicom         # Serial terminal — useful for debugging UART devices
  ];

  # =========================================================================
  # Disable audio — server doesn't need it
  # =========================================================================
  services.pipewire.enable      = lib.mkForce false;

  # =========================================================================
  # Disable suspend/sleep
  # =========================================================================
  systemd.targets.sleep.enable        = false;
  systemd.targets.suspend.enable      = false;
  systemd.targets.hibernate.enable    = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.settings.Login = {
    HandleSuspendKey            = "ignore";
    HandleHibernateKey          = "ignore";
    HandleLidSwitch             = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction                  = "ignore";
  };

  # =========================================================================
  # Server network optimizations — same as MinisForum
  # =========================================================================
  boot.kernel.sysctl = {
    "net.core.rmem_max"           = 134217728;
    "net.core.wmem_max"           = 134217728;
    "net.ipv4.tcp_rmem"           = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"           = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;
    "fs.inotify.max_user_watches" = 524288;
  };

  # =========================================================================
  # FreshRSS — self-hosted RSS/Atom feed reader
  #
  # Web UI: http://Radxa-X4:8080
  #
  # The NixOS module automatically configures nginx as the web server.
  # We serve on port 8080 instead of 80 to keep port 80 free for anything
  # else that might land on this server later.
  #
  # The admin password is managed by agenix. Create the secret once:
  #   nix run nixpkgs#agenix -- -e secrets/freshrss-admin-password.age
  #   (Type the password, save, close)
  #
  # After first boot:
  #   1. Open http://Radxa-X4:8080 — login directly (no setup wizard)
  #   2. Username: linuxury, Password: whatever is in freshrss-admin-password.age
  #   3. Add feeds manually or import an OPML file
  #   4. FreshRSS supports the GReader API for mobile apps
  #      (compatible with: Reeder, FeedMe, Fluent Reader, etc.)
  #   5. Enable API: Configuration → Authentication → Allow API access
  # =========================================================================

  # agenix decrypts the password at activation and places it at this path
  age.secrets.freshrss-admin-password = {
    file  = ../../secrets/freshrss-admin-password.age;
    owner = "freshrss";
    mode  = "0400";
  };

  services.freshrss = {
    enable       = true;
    baseUrl      = "http://radxa-x4.tail1023a0.ts.net:8080";
    defaultUser  = "linuxury";
    passwordFile = config.age.secrets.freshrss-admin-password.path;
    virtualHost  = "freshrss";
    # Database: SQLite is the default and perfectly adequate
    # for a single-user RSS reader. No extra database service needed.

    # GReader API + Fever API — required for mobile clients
    # (FeedMe, Reeder, Fluent Reader, etc.)
    # After enabling: each user must set an API password in their profile
    # under Profile → API management.
    api.enable = true;

    # Declarative extensions — deployed read-only to THIRDPARTY_EXTENSIONS_PATH.
    # The web UI (Administration → Extensions) can still manage additional
    # extensions uploaded to DATA_PATH/extensions/ (/var/lib/freshrss/extensions/).
    extensions = with pkgs.freshrss-extensions; [

      # -----------------------------------------------------------------------
      # From nixpkgs (pkgs.freshrss-extensions)
      # -----------------------------------------------------------------------
      auto-ttl          # Automatic feed TTL based on update frequency
      youtube           # Embed YouTube/PeerTube videos in feeds
      title-wrap        # Wrap long titles instead of truncating
      unsafe-auto-login # Restore autologin via URL token
      reading-time      # Estimated reading time per article

      # -----------------------------------------------------------------------
      # From official FreshRSS/Extensions repo (same nixpkgs-pinned commit)
      # -----------------------------------------------------------------------
      # Captcha — skip CAPTCHA-protected feeds via bypass logic
      (buildExt {
        FreshRssExtUniqueId = "Captcha";
        pname   = "captcha";
        version = "1.0.1";
        src     = officialSrc;
        sourceRoot = "source/xExtension-Captcha";
      })

      # ColorfulList — color-code feed categories in the sidebar
      (buildExt {
        FreshRssExtUniqueId = "ColorfulList";
        pname   = "colorful-list";
        version = "0.3.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-ColorfulList";
      })

      # ImageProxy — proxy external images through the FreshRSS server
      # (prevents external image-based tracking)
      (buildExt {
        FreshRssExtUniqueId = "ImageProxy";
        pname   = "image-proxy";
        version = "1.0";
        src     = officialSrc;
        sourceRoot = "source/xExtension-ImageProxy";
      })

      # QuickCollapse — keyboard shortcut to collapse/expand categories
      (buildExt {
        FreshRssExtUniqueId = "QuickCollapse";
        pname   = "quick-collapse";
        version = "1.0.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-QuickCollapse";
      })

      # ShareByEmail — share article links via mailto: links
      (buildExt {
        FreshRssExtUniqueId = "ShareByEmail";
        pname   = "share-by-email";
        version = "0.3.3";
        src     = officialSrc;
        sourceRoot = "source/xExtension-ShareByEmail";
      })

      # StickyFeeds — pin feeds to the top of the sidebar
      (buildExt {
        FreshRssExtUniqueId = "StickyFeeds";
        pname   = "sticky-feeds";
        version = "0.2.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-StickyFeeds";
      })

      # WordHighlighter — highlight keywords in article titles/content
      (buildExt {
        FreshRssExtUniqueId = "WordHighlighter";
        pname   = "word-highlighter";
        version = "0.0.3";
        src     = officialSrc;
        sourceRoot = "source/xExtension-WordHighlighter";
      })

      # showFeedID — display the internal feed ID (useful for API usage)
      (buildExt {
        FreshRssExtUniqueId = "showFeedID";
        pname   = "show-feed-id";
        version = "0.4.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-showFeedID";
      })

      # -----------------------------------------------------------------------
      # Auto Refresh — github.com/Eisa01/FreshRSS---Auto-Refresh-Extension
      # Reloads the web UI automatically when idle. Enable per-user in Settings.
      # -----------------------------------------------------------------------
      (buildExt {
        FreshRssExtUniqueId = "AutoRefresh";
        pname   = "auto-refresh";
        version = "1.4";
        src     = autoRefreshSrc;
        sourceRoot = "source/xExtension-AutoRefresh";
      })

      # -----------------------------------------------------------------------
      # Comics in Feed — github.com/giventofly/freshrss-comicsinfeed
      # Embeds comic strip images directly in feeds (xkcd, Penny Arcade, etc.)
      # Enable per-user in Settings → Extensions.
      # -----------------------------------------------------------------------
      (buildExt {
        FreshRssExtUniqueId = "ComicsInFeed";
        pname   = "comics-in-feed";
        version = "1.5.1";
        src     = pkgs.fetchFromGitHub {
          owner = "giventofly";
          repo  = "freshrss-comicsinfeed";
          rev   = "525027dafe9c6a80c4aee4b11cee1007416bad7a";
          hash  = "sha256-9G7B3SfpaXJQmJ4WL0VwkEkdXZuCflRWonX+lzIKfKc=";
        };
      })

      # -----------------------------------------------------------------------
      # FlareSolverr — github.com/ravenscroftj/freshrss-flaresolverr-extension
      # Routes Cloudflare-protected feeds through a FlareSolverr instance.
      # Requires a running FlareSolverr service; configure the URL in Settings.
      # System-level extension (always active once installed).
      # -----------------------------------------------------------------------
      (buildExt {
        FreshRssExtUniqueId = "FlareSolverr";
        pname   = "flare-solverr";
        version = "0.4.3";
        src     = pkgs.fetchFromGitHub {
          owner = "ravenscroftj";
          repo  = "freshrss-flaresolverr-extension";
          rev   = "f01c02dff8cf26dc6e5a52fe3443aa321a3a620a";
          hash  = "sha256-GiC8mYBN/Y22/tB++HLMHUKJViMV9h2hNrI5upXodNM=";
        };
      })

      # -----------------------------------------------------------------------
      # Image Cache — github.com/Victrid/freshrss-image-cache-plugin
      # Caches feed images via an external service (Cloudflare or self-hosted).
      # Configure the cache endpoint in Settings → Extensions.
      # -----------------------------------------------------------------------
      (buildExt {
        FreshRssExtUniqueId = "ImageCache";
        pname   = "image-cache";
        version = "0.4.1";
        src     = pkgs.fetchFromGitHub {
          owner = "Victrid";
          repo  = "freshrss-image-cache-plugin";
          rev   = "v0.4.1";
          hash  = "sha256-qIY4lx3m/vDMRNOyNNhHr5Eu717RBomYAnXV1gZewVw=";
        };
      })

      # -----------------------------------------------------------------------
      # Clickable Links — github.com/kapdap/freshrss-extensions
      # Converts plain-text URLs in article content into clickable links.
      # Enable per-user in Settings → Extensions.
      # -----------------------------------------------------------------------
      (buildExt {
        FreshRssExtUniqueId = "ClickableLinks";
        pname   = "clickable-links";
        version = "1.01";
        src     = kapdapSrc;
        sourceRoot = "source/xExtension-ClickableLinks";
      })

      # -----------------------------------------------------------------------
      # RSS-Bridge — github.com/DevonHess/FreshRSS-Extensions
      # Detects and rewrites feed URLs through an RSS-Bridge instance.
      # System-level extension; configure your RSS-Bridge URL in Settings.
      # -----------------------------------------------------------------------
      (buildExt {
        FreshRssExtUniqueId = "RssBridge";
        pname   = "rss-bridge";
        version = "1.1";
        src     = devonSrc;
        sourceRoot = "source/xExtension-RssBridge";
      })

      # -----------------------------------------------------------------------
      # Twitch Channel → RSS — github.com/babico/xExtension-TwitchChannel2RssFeed
      # Converts a Twitch channel URL into an RSS feed URL when subscribing.
      # Enable per-user in Settings → Extensions.
      # -----------------------------------------------------------------------
      (buildExt {
        FreshRssExtUniqueId = "TwitchChannel2RssFeed";
        pname   = "twitch-channel-2-rss-feed";
        version = "0.2";
        src     = pkgs.fetchFromGitHub {
          owner = "babico";
          repo  = "xExtension-TwitchChannel2RssFeed";
          rev   = "c164823aeaf9a734bb03bf50b3628704b61c90aa";
          hash  = "sha256-yAtnhd9n4v3E/prkjhxUgpmT6nUDcAJmjR6Uho0dQ7k=";
        };
      })

      # -----------------------------------------------------------------------
      # CNTools extensions — github.com/cn-tools/cntools_FreshRssExtensions
      # -----------------------------------------------------------------------

      # BlackList — block/hide entries matching a keyword blacklist (system)
      (buildExt {
        FreshRssExtUniqueId = "BlackList";
        pname   = "cn-black-list";
        version = "0.0.1";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-BlackList";
      })

      # Copy2Clipboard — copies visible entry URLs to clipboard (user)
      (buildExt {
        FreshRssExtUniqueId = "Copy2Clipboard";
        pname   = "cn-copy-2-clipboard";
        version = "0.4";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-Copy2Clipboard";
      })

      # FeedTitleBuilder — customise feed titles based on URL/date (user)
      (buildExt {
        FreshRssExtUniqueId = "FeedTitleBuilder";
        pname   = "cn-feed-title-builder";
        version = "0.2";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-FeedTitleBuilder";
      })

      # FilterTitle — hide entries whose title matches filter keywords (system)
      (buildExt {
        FreshRssExtUniqueId = "FilterTitle";
        pname   = "cn-filter-title";
        version = "0.1.0";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-FilterTitle";
      })

      # RemoveEmojis — strips emojis from newly ingested entry titles (user)
      (buildExt {
        FreshRssExtUniqueId = "RemoveEmojis";
        pname   = "cn-remove-emojis";
        version = "0.1-dev";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-RemoveEmojis";
      })

      # SendToMyJD2 — sends article links to a JDownloader 2 instance (user)
      (buildExt {
        FreshRssExtUniqueId = "SendToMyJD2";
        pname   = "cn-send-to-my-jd2";
        version = "0.0.1-alpha";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-SendToMyJD2";
      })

      # YouTubeChannel2RssFeed — converts YouTube channel URL to RSS (user)
      (buildExt {
        FreshRssExtUniqueId = "YouTubeChannel2RssFeed";
        pname   = "cn-youtube-channel-2-rss-feed";
        version = "0.6.1";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-YouTubeChannel2RssFeed";
      })

    ];
  };

  # Override the nginx virtualHost to listen on port 8080 instead of 80.
  # The freshrss module sets everything else (root, PHP-FPM, locations).
  services.nginx.virtualHosts.freshrss = {
    listen = [{ addr = "0.0.0.0"; port = 8080; }];
  };

  # Open port 8080 for FreshRSS
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Ensure freshrss-config.service runs AFTER agenix has decrypted secrets.
  # Without this, the service races against agenix at boot and reads an empty
  # password file, creating the admin account with a blank password.
  systemd.services.freshrss-config = {
    after  = [ "agenix.service" ];
    wants  = [ "agenix.service" ];
  };

  # =========================================================================
  # Users — same three family accounts for Samba
  # =========================================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "networkmanager" "gpio" ];
      # gpio group added so linuxury can use GPIO pins without sudo
      shell        = pkgs.fish;
    };

    babylinux = {
      isNormalUser = true;
      extraGroups  = [ "networkmanager" ];
      shell        = pkgs.fish;
    };

    alex = {
      isNormalUser = true;
      extraGroups  = [];
      shell        = pkgs.fish;
    };
  };

  programs.fish.enable = true;
}
