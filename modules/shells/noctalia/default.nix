# ===========================================================================
# modules/shells/noctalia/default.nix — Noctalia shell layer
#
# Quickshell-based desktop shell: bar, launcher, notifications, widgets.
# Originally paired with MangoWC but works on any wlr-layer-shell compositor.
#
# Binary cache: noctalia.cachix.org — avoids recompiling Qt/Quickshell (~30m).
#
# Importing this module activates Noctalia. No enable flag needed.
# Noctalia does not provide a login screen — add greeters/sddm to your host.
#
# To switch shell: remove this import, add shells/dms or shells/wayle.
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # Binary cache — pre-built Noctalia + Quickshell binaries
  # Without this, the first build recompiles Qt from source (~30 min).
  # =========================================================================
  nix.settings = {
    extra-substituters      = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # =========================================================================
  # Packages — shell layer + Quickshell toolkit
  # =========================================================================
  environment.systemPackages = with pkgs; [
    noctalia-shell   # Shell layer: bar, launcher, notifications, widgets
    noctalia-qs      # Quickshell-based QtQuick toolkit used by noctalia-shell
  ];

  # =========================================================================
  # Home Manager — color sync + Hyprland shell-active.conf
  # =========================================================================
  home-manager.sharedModules = [

    # Sync MangoWC focus border color with Noctalia's active accent (mPrimary).
    # Path unit watches ~/.config/noctalia/colors.json for changes.
    # Safe on non-MangoWC compositors — the mmsg call exits cleanly if
    # MangoWC is not running.
    ./color-sync/default.nix

    # Clear shell-active.conf — Noctalia does not need Hyprland source
    # overrides (it manages its own layer via wlr-layer-shell directly).
    ({ lib, ... }: {
      home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-active.conf"
        [ -d "$(dirname "$_target")" ] || exit 0
        : > "$_target"
      '';
    })

  ];
}
