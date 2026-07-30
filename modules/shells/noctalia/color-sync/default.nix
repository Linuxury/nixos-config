# ===========================================================================
# modules/shells/noctalia/color-sync/default.nix
#
# Fires when Noctalia writes ~/.config/noctalia/colors.json after its own
# material-color pass. Writes mPrimary to ~/.local/share/current-wallpaper-color
# and clears the matugen dedup stamp, then starts matugen.service. This causes
# matugen to re-run using Noctalia's color instead of the ImageMagick fallback,
# keeping Hyprland borders in sync with the bar accent.
# ===========================================================================

{ pkgs, ... }:

{
  systemd.user.services.noctalia-color-sync = {
    Unit.Description = "Sync colors from Noctalia palette to compositor + matugen";

    Service = {
      Type      = "oneshot";
      ExecStart = "${pkgs.writeShellScript "noctalia-color-sync" ''
        COLORS="$HOME/.config/noctalia/colors.json"
        HINT="$HOME/.local/share/current-wallpaper-color"
        STAMP="$HOME/.local/share/last-matugen-processed"

        [ -f "$COLORS" ] || exit 0

        HEX=$(${pkgs.jq}/bin/jq -r '.mPrimary' "$COLORS")
        [ -n "$HEX" ] && [ "$HEX" != "null" ] || exit 0
        HEX_BARE=''${HEX#\#}

        # Write color hint and clear matugen dedup stamp so matugen re-runs
        # with Noctalia's mPrimary instead of the ImageMagick fallback.
        printf '%s\n' "$HEX" > "$HINT"
        rm -f "$STAMP"
        systemctl --user start matugen.service
      ''}";
    };
  };

  systemd.user.paths.noctalia-color-sync = {
    Unit.Description  = "Watch Noctalia colors.json for palette changes";
    Path.PathModified = "%h/.config/noctalia/colors.json";
    Install.WantedBy  = [ "default.target" ];
  };
}
