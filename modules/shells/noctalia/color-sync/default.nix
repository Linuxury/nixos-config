# ===========================================================================
# modules/shells/noctalia/color-sync/default.nix
#
# Keeps MangoWC's focuscolor in sync with Noctalia's accent (mPrimary).
#
# Noctalia writes ~/.config/noctalia/colors.json whenever the wallpaper
# changes and it derives a new accent. A path unit detects that write,
# then the service extracts mPrimary, reformats it for MangoWC (0xRRGGBBff),
# patches focuscolor in-place, and reloads the compositor config.
# ===========================================================================

{ pkgs, ... }:

{
  systemd.user.services.noctalia-color-sync = {
    Unit.Description = "Sync MangoWC focus border with Noctalia accent color";

    Service = {
      Type      = "oneshot";
      ExecStart = "${pkgs.writeShellScript "noctalia-color-sync" ''
        COLORS="$HOME/.config/noctalia/colors.json"
        MANGO="$HOME/.config/mango/config.conf"

        [ -f "$COLORS" ] || exit 0
        [ -f "$MANGO"  ] || exit 0

        HEX=$(${pkgs.jq}/bin/jq -r '.mPrimary | ltrimstr("#")' "$COLORS")
        [ -n "$HEX" ] || exit 0

        ${pkgs.gnused}/bin/sed -i "s/^focuscolor=.*/focuscolor=0x''${HEX}ff/" "$MANGO"
        mmsg -d reload_config 2>&1 || echo "mmsg failed"
      ''}";
    };
  };

  systemd.user.paths.noctalia-color-sync = {
    Unit.Description  = "Watch Noctalia colors.json for accent changes";
    Path.PathModified = "%h/.config/noctalia/colors.json";
    Install.WantedBy  = [ "default.target" ];
  };
}
