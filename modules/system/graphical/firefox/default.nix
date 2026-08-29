# ===========================================================================
# modules/system/graphical/firefox/default.nix — Firefox
#
# Installs Firefox. By default also deploys the "de-slop" managed policy
# (../../../../dotfiles/firefox/policies.json) to /etc/firefox/policies/
# policies.json — telemetry/AI/password-manager off, uBlock Origin and
# Proton Pass force-installed, uBlock preloaded with a hardened filter list
# plus the yt-shorts hider (github.com/gijsdev/ublock-hide-yt-shorts). Set
# programs.firefox.deSlop.enable = false; on a host to opt out.
#
# The uBlock filterLists/externalLists set is duplicated in
# dotfiles/chromium/policies.json (different browser, same extension) —
# keep them in sync by hand when editing either.
# Imported per-host via the host imports list.
# ===========================================================================

{ config, lib, ... }:

let
  cfg = config.programs.firefox;
in

{
  options.programs.firefox.deSlop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Deploy the de-slop managed policy (dotfiles/firefox/policies.json).";
  };

  config = lib.mkMerge [
    { programs.firefox.enable = true; }

    (lib.mkIf cfg.deSlop.enable {
      programs.firefox.policies =
        (builtins.fromJSON (builtins.readFile ../../../../dotfiles/firefox/policies.json)).policies;
    })

    {
      # userChrome.css — profile dir has a random suffix (e.g.
      # yhtttubw.default under NixOS's ~/.config/mozilla/firefox/, not the
      # traditional ~/.mozilla/firefox/), so it can't be a static home.file
      # path. Discovered at activation time instead; live symlink so edits
      # in the repo take effect on next Firefox restart, no rebuild needed.
      # home-manager.sharedModules applies this to every user on the host
      # (moved here from users/linuxury/home.nix, which only covered one).
      home-manager.sharedModules = [
        ({ lib, ... }: {
          home.activation.firefoxUserChrome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            _profile=$(ls -d "$HOME/.config/mozilla/firefox/"*.default* 2>/dev/null | head -1)
            if [ -n "$_profile" ]; then
              mkdir -p "$_profile/chrome"
              ln -sf "$HOME/nixos-config/dotfiles/firefox/userChrome.css" "$_profile/chrome/userChrome.css"
            fi
          '';
        })
      ];
    }
  ];

  # gfx.color_management.hdr / .force_enabled — tried for Linux/Wayland HDR
  # video playback, reverted. Confirmed live: HDR did engage (Hyprland
  # switched the monitor to HDR mode), but video rendered with a blown-out
  # red tint — matches Mozilla's own tracked regressions for this feature
  # (bugzilla 1642854 "HDR video support for Linux" and related Wayland
  # color-management reports: "HDR video on YouTube appears blown out
  # compared to properly configured video players"). This is a genuine
  # upstream Gecko bug, not fixable from config — revisit once Mozilla
  # lands a fix. Broken red-tinted HDR is worse than normal SDR, so left off.
}
