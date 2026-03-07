# ===========================================================================
# hosts/Media-Server/freshrss.nix — FreshRSS feed reader
#
# Migrated from Radxa-X4.
#
# Web UI: http://Media-Server:8080  (LAN)
#         http://media-server.tail1023a0.ts.net:8080  (Tailscale)
#
# Data migration from Radxa — run once after first deploy:
#   On Radxa-X4:
#     sudo systemctl stop freshrss freshrss-updater freshrss-config
#     sudo tar -czf /tmp/freshrss-data.tar.gz /var/lib/freshrss
#     scp /tmp/freshrss-data.tar.gz media-server:/tmp/
#   On Media-Server:
#     sudo tar -xzf /tmp/freshrss-data.tar.gz -C /
#     sudo chown -R freshrss:freshrss /var/lib/freshrss
#     sudo systemctl restart freshrss freshrss-updater
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  buildExt = pkgs.freshrss-extensions.buildFreshRssExtension;

  officialSrc = pkgs.fetchFromGitHub {
    owner = "FreshRSS";
    repo  = "Extensions";
    rev   = "42c32bfd9af2d816933cf310e24d25888a8e167d";
    hash  = "sha256-El488QK3xWQM01GsuyBizud6VghXsRDqiOblnMfjVxE=";
  };

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
  # Agenix secret — same file, now decrypted for Media-Server's host key
  age.secrets.freshrss-admin-password = {
    file  = ../../secrets/freshrss-admin-password.age;
    owner = "freshrss";
    mode  = "0400";
  };

  services.freshrss = {
    enable       = true;
    baseUrl      = "http://media-server.tail1023a0.ts.net:8080";
    defaultUser  = "linuxury";
    passwordFile = config.age.secrets.freshrss-admin-password.path;
    virtualHost  = "freshrss";
    api.enable   = true;

    extensions = with pkgs.freshrss-extensions; [

      # From nixpkgs
      auto-ttl
      youtube
      title-wrap
      unsafe-auto-login
      reading-time

      # Official FreshRSS/Extensions repo
      (buildExt {
        FreshRssExtUniqueId = "Captcha";
        pname   = "captcha";
        version = "1.0.1";
        src     = officialSrc;
        sourceRoot = "source/xExtension-Captcha";
      })
      (buildExt {
        FreshRssExtUniqueId = "ColorfulList";
        pname   = "colorful-list";
        version = "0.3.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-ColorfulList";
      })
      (buildExt {
        FreshRssExtUniqueId = "ImageProxy";
        pname   = "image-proxy";
        version = "1.0";
        src     = officialSrc;
        sourceRoot = "source/xExtension-ImageProxy";
      })
      (buildExt {
        FreshRssExtUniqueId = "QuickCollapse";
        pname   = "quick-collapse";
        version = "1.0.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-QuickCollapse";
      })
      (buildExt {
        FreshRssExtUniqueId = "ShareByEmail";
        pname   = "share-by-email";
        version = "0.3.3";
        src     = officialSrc;
        sourceRoot = "source/xExtension-ShareByEmail";
      })
      (buildExt {
        FreshRssExtUniqueId = "StickyFeeds";
        pname   = "sticky-feeds";
        version = "0.2.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-StickyFeeds";
      })
      (buildExt {
        FreshRssExtUniqueId = "WordHighlighter";
        pname   = "word-highlighter";
        version = "0.0.3";
        src     = officialSrc;
        sourceRoot = "source/xExtension-WordHighlighter";
      })
      (buildExt {
        FreshRssExtUniqueId = "showFeedID";
        pname   = "show-feed-id";
        version = "0.4.2";
        src     = officialSrc;
        sourceRoot = "source/xExtension-showFeedID";
      })

      # Auto Refresh
      (buildExt {
        FreshRssExtUniqueId = "AutoRefresh";
        pname   = "auto-refresh";
        version = "1.4";
        src     = autoRefreshSrc;
        sourceRoot = "source/xExtension-AutoRefresh";
      })

      # Comics in Feed
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

      # FlareSolverr
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

      # Image Cache
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

      # Clickable Links
      (buildExt {
        FreshRssExtUniqueId = "ClickableLinks";
        pname   = "clickable-links";
        version = "1.01";
        src     = kapdapSrc;
        sourceRoot = "source/xExtension-ClickableLinks";
      })

      # RSS-Bridge
      (buildExt {
        FreshRssExtUniqueId = "RssBridge";
        pname   = "rss-bridge";
        version = "1.1";
        src     = devonSrc;
        sourceRoot = "source/xExtension-RssBridge";
      })

      # Twitch Channel → RSS
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

      # CNTools extensions
      (buildExt {
        FreshRssExtUniqueId = "BlackList";
        pname   = "cn-black-list";
        version = "0.0.1";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-BlackList";
      })
      (buildExt {
        FreshRssExtUniqueId = "Copy2Clipboard";
        pname   = "cn-copy-2-clipboard";
        version = "0.4";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-Copy2Clipboard";
      })
      (buildExt {
        FreshRssExtUniqueId = "FeedTitleBuilder";
        pname   = "cn-feed-title-builder";
        version = "0.2";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-FeedTitleBuilder";
      })
      (buildExt {
        FreshRssExtUniqueId = "FilterTitle";
        pname   = "cn-filter-title";
        version = "0.1.0";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-FilterTitle";
      })
      (buildExt {
        FreshRssExtUniqueId = "RemoveEmojis";
        pname   = "cn-remove-emojis";
        version = "0.1-dev";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-RemoveEmojis";
      })
      (buildExt {
        FreshRssExtUniqueId = "SendToMyJD2";
        pname   = "cn-send-to-my-jd2";
        version = "0.0.1-alpha";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-SendToMyJD2";
      })
      (buildExt {
        FreshRssExtUniqueId = "YouTubeChannel2RssFeed";
        pname   = "cn-youtube-channel-2-rss-feed";
        version = "0.6.1";
        src     = cntoolsSrc;
        sourceRoot = "source/xExtension-YouTubeChannel2RssFeed";
      })

    ];
  };

  # Serve on port 8080; the freshrss module handles PHP-FPM and locations
  services.nginx.virtualHosts.freshrss = {
    listen = [{ addr = "0.0.0.0"; port = 8080; }];
  };

  networking.firewall.allowedTCPPorts = lib.mkAfter [ 8080 ];

  # Ensure freshrss-config runs after agenix so it reads a populated password file
  systemd.services.freshrss-config = {
    after = [ "agenix.service" ];
    wants = [ "agenix.service" ];
  };
}
