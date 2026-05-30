# ===========================================================================
# modules/compositors/hyprland/matugen/default.nix — matugen color sync
#
# Same structural pattern as services/wallpaper-slideshow/default.nix (COSMIC):
#   - wallpaper-service.ts writes ~/.local/share/last-matugen-wallpaper
#     when the wallpaper changes.
#   - A systemd path unit detects that write and triggers the service.
#   - The service extracts the dominant color and runs matugen.
#   - A startup timer runs the service 5s after session start so colors
#     are always in sync even if the wallpaper didn't change.
#   - Deduplication prevents running twice for the same wallpaper.
#
# Benefit over the old inline approach: matugen runs in a separate process
# after the wallpaper is already set, and never runs more than once per
# unique wallpaper — eliminating the rapid double-run that crashed GTK4 apps.
# ===========================================================================
{ config, pkgs, lib, ... }:

{
  imports = [];

  home.packages = with pkgs; [
    matugen
    imagemagick
  ];

  # =========================================================================
  # Color sync service — runs matugen when Wayle changes the wallpaper
  #
  # Wayle's awww engine sets the wallpaper and writes its own matugen palette
  # to ~/.cache/wayle/matugen-colors.json. The path unit below watches that
  # file. When it changes, this service asks Wayle for the current wallpaper
  # path, extracts the dominant color, and runs our matugen for the remaining
  # templates (hyprland colors, kitty, gtk, hyprlock, rofi).
  #
  # Deduplication skips the run if the same wallpaper was already processed.
  # =========================================================================
  systemd.user.services.matugen = {
    Unit = {
      Description = "Apply matugen color theme for current Hyprland wallpaper";
      After       = [ "graphical-session.target" ];
      # Allow rapid triggers without systemd rate-limiting the service
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type        = "oneshot";
      ExecStart   = "${pkgs.writeShellScript "matugen" ''
        PROC_FILE="$HOME/.local/share/last-matugen-processed"
        LOG="$HOME/.local/share/wallpaper-service.log"

        log() { echo "[$(date "+%H:%M:%S")] MATUGEN $*" >> "$LOG"; }

        # Get current wallpaper path from Wayle
        WALLPAPER=$(${pkgs.wayle}/bin/wayle wallpaper info 2>/dev/null \
          | grep '^Current:' | sed 's/^Current:[[:space:]]*//')
        if [ -z "$WALLPAPER" ] || [ "$WALLPAPER" = "(none)" ] || [ ! -f "$WALLPAPER" ]; then
          log "No current wallpaper from Wayle"
          exit 0
        fi

        # Deduplication — skip if this wallpaper's colors are already applied
        LAST_PROC=$(cat "$PROC_FILE" 2>/dev/null || echo "")
        if [ -n "$LAST_PROC" ] && [ "$WALLPAPER" = "$LAST_PROC" ]; then exit 0; fi
        echo "$WALLPAPER" > "$PROC_FILE"

        log "Applying: $(basename "$WALLPAPER")"

        HEX=$(${pkgs.imagemagick}/bin/convert "$WALLPAPER" -resize 1x1 txt:- 2>/dev/null \
          | grep -oP "#[0-9A-Fa-f]{6}" | head -1)
        if [ -z "$HEX" ]; then log "WARN no color from $(basename "$WALLPAPER")"; exit 0; fi

        log "Color: $HEX"
        ${pkgs.matugen}/bin/matugen color hex "$HEX" >> "$LOG" 2>&1 \
          || log "WARN matugen failed"
        log "Done"
      ''}";
    };
  };

  # =========================================================================
  # Path unit — triggers the service when Wayle updates its matugen palette
  # Wayle writes this file when the wallpaper changes (theme-provider=matugen).
  # =========================================================================
  systemd.user.paths.matugen = {
    Unit.Description = "Watch Wayle matugen palette for wallpaper changes";
    Path.PathChanged  = "%h/.cache/wayle/matugen-colors.json";
    Install.WantedBy  = [ "graphical-session.target" ];
  };

  # =========================================================================
  # Startup timer — ensures colors are applied at session start
  # Wayle needs a few seconds to initialize and set the first wallpaper,
  # so 10s gives the engine time to run before we query it.
  # =========================================================================
  systemd.user.timers.matugen = {
    Unit.Description    = "Apply matugen colors on session start";
    Timer.OnActiveSec   = "10s";
    Install.WantedBy    = [ "graphical-session.target" ];
  };

  home.file.".config/matugen/config.toml".text = ''
    [config]
    mode = "dark"
    reload_apps = false

    # Wayle handles its own theming via theme-provider=matugen (writes
    # ~/.cache/wayle/matugen-colors.json internally). These templates handle
    # the rest of the Hyprland ecosystem.

    [templates.hyprland]
    input_path = "/home/linuxury/.config/matugen/templates/templates/hyprland-colors.conf"
    output_path = "/home/linuxury/.config/hypr/colors.conf"

    [templates.kitty]
    input_path = "/home/linuxury/.config/matugen/templates/templates/kitty-colors.conf"
    output_path = "/home/linuxury/.config/kitty/colors.conf"
    # post_hook removed: pkill -USR1 kitty was crashing open terminals on every
    # wallpaper switch. Colors.conf is still written so new windows pick up the
    # palette; existing windows keep the previous colors until reopened.

    [templates.gtk]
    input_path = "/home/linuxury/.config/matugen/templates/templates/gtk-colors.css"
    output_path = "/home/linuxury/.config/gtk-4.0/colors.css.new"
    post_hook = "mv -f /home/linuxury/.config/gtk-4.0/colors.css.new /home/linuxury/.config/gtk-4.0/colors.css"

    [templates.gtk-libadwaita]
    input_path = "/home/linuxury/nixos-config/dotfiles/hypr/gtk-libadwaita.css.template"
    output_path = "/home/linuxury/.config/gtk-4.0/libadwaita-matugen.css.new"
    post_hook = "mv -f /home/linuxury/.config/gtk-4.0/libadwaita-matugen.css.new /home/linuxury/.config/gtk-4.0/libadwaita-matugen.css"

    [templates.rofi-window]
    input_path = "/home/linuxury/nixos-config/dotfiles/hypr/rofi/window.rasi.template"
    output_path = "/home/linuxury/.config/rofi/window.rasi"

    [templates.hyprlock]
    input_path = "/home/linuxury/.config/matugen/templates/templates/hyprlock-colors.conf"
    output_path = "/home/linuxury/.config/hypr/colors-hyprlock.conf"
  '';
}
