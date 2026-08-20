# ===========================================================================
# modules/system/graphical/helium/default.nix — Helium browser
#
# Helium is a privacy-focused Chromium-based browser with built-in ad/
# tracker blocking, split-view, and !bang search shortcuts.
# Not in nixpkgs — installed via the helium-browser community flake.
#
# The desktop entry override passes --password-store=gnome-libsecret so
# Helium connects to the already-unlocked system keyring at login instead
# of prompting for credentials on every launch.
#
# Enable per host by importing this module:
#   ../../modules/system/graphical/helium/default.nix
#
# By default also deploys the "de-slop" managed policy
# (../../../../dotfiles/chromium/policies.json) to
# /etc/chromium/policies/managed/policies.json — telemetry/tracking/password-
# manager off, uBlock Origin and Proton Pass force-installed, uBlock preloaded
# with a hardened filter list plus the yt-shorts hider
# (github.com/gijsdev/ublock-hide-yt-shorts). Helium
# bundles its own uBlock Origin fork and its extension model (MV2 vs MV3,
# and whether it even reads the standard Chromium policy path) hasn't been
# confirmed live — check chrome://policy and chrome://extensions after
# enabling. Set programs.helium.deSlop.enable = false; on a host to opt out.
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

let
  cfg = config.programs.helium;
in

{
  options.programs.helium.deSlop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Deploy the de-slop managed policy (dotfiles/chromium/policies.json).";
  };

  config = lib.mkMerge [
    {
      # =======================================================================
      # Helium — system package (available to all users on this host)
      # =======================================================================
      environment.systemPackages = [
        inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.helium
      ];
    }

    (lib.mkIf cfg.deSlop.enable {
      environment.etc."chromium/policies/managed/policies.json".source =
        ../../../../dotfiles/chromium/policies.json;
    })

    {
      # =======================================================================
      # Desktop entry override — bind Helium to the system keyring
      #
      # Placed in ~/.local/share/applications/ so it shadows the package's entry
      # in XDG_DATA_DIRS. Using home-manager.sharedModules applies it to every
      # user on this host without a separate per-user import.
      # =======================================================================
      home-manager.sharedModules = [
        {
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
      ];
    }
  ];
}
