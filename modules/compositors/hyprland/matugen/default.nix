# ===========================================================================
# modules/compositors/hyprland/matugen/default.nix — matugen color sync
#
# Path unit watches ~/.local/share/current-wallpaper (written by Noctalia's
# wallpaperChange hook). On change, the service extracts the dominant color,
# runs matugen 3× to work around a matugen 4.0.0 HashMap iteration bug that
# causes it to crash after processing only 2–3 of 5 templates per run, then
# reloads Hyprland config so colors.lua (written by matugen) takes effect.
# A startup timer fires 10s after session start for initial color sync.
# ===========================================================================
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    matugen
    imagemagick
  ];

  systemd.user.services.matugen = {
    Unit = {
      Description = "Apply matugen color theme for current Hyprland wallpaper";
      After       = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type        = "oneshot";
      ExecStart   = "${pkgs.writeShellScript "matugen" ''
        PROC_FILE="$HOME/.local/share/last-matugen-processed"
        LOG="$HOME/.local/share/wallpaper-service.log"
        CURRENT_WALLPAPER_FILE="$HOME/.local/share/current-wallpaper"
        SDDM_WALLPAPER="/var/lib/sddm-wallpaper/background.jpg"

        log() { echo "[$(date "+%H:%M:%S")] MATUGEN $*" >> "$LOG"; }

        WALLPAPER=$(cat "$CURRENT_WALLPAPER_FILE" 2>/dev/null | tr -d '\n')
        if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
          log "No current wallpaper (''${CURRENT_WALLPAPER_FILE} empty or target missing)"
          exit 0
        fi

        # Deduplication — skip if this wallpaper's colors are already applied.
        # Also check colors.lua exists: HM activation can rewrite ~/.config/hypr/
        # and delete it while the stamp still holds the same path.
        COLORS_LUA="$HOME/.config/hypr/colors.lua"
        LAST_PROC=$(cat "$PROC_FILE" 2>/dev/null || echo "")
        if [ -n "$LAST_PROC" ] && [ "$WALLPAPER" = "$LAST_PROC" ] && [ -f "$COLORS_LUA" ]; then
          exit 0
        fi
        echo "$WALLPAPER" > "$PROC_FILE"

        log "Applying: $(basename "$WALLPAPER")"

        HEX=$(${pkgs.imagemagick}/bin/convert "$WALLPAPER" -resize 1x1 txt:- 2>/dev/null \
          | grep -oP "#[0-9A-Fa-f]{6}" | head -1)
        if [ -z "$HEX" ]; then log "WARN no color from $(basename "$WALLPAPER")"; exit 0; fi

        log "Color: $HEX"

        # matugen 4.0.0 has a HashMap iteration bug: it crashes after processing
        # only 2–3 of 5 templates per run. Running 3× ensures full coverage.
        ${pkgs.matugen}/bin/matugen color hex "$HEX" >> "$LOG" 2>&1 || true
        ${pkgs.matugen}/bin/matugen color hex "$HEX" >> "$LOG" 2>&1 || true
        ${pkgs.matugen}/bin/matugen color hex "$HEX" >> "$LOG" 2>&1 || true

        # Reload Hyprland config so colors.lua (written by matugen) takes effect.
        # hyprctl keyword no longer works with the Lua parser — reload is the
        # correct mechanism since Hyprland 0.41+ with non-legacy configs.
        hyprctl reload >> "$LOG" 2>&1 && log "Hyprland reloaded" || log "WARN hyprctl reload failed"

        if [ -d "$(dirname "$SDDM_WALLPAPER")" ]; then
          cp "$WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null \
            && log "SDDM wallpaper synced: $(basename "$WALLPAPER")" \
            || log "WARN SDDM wallpaper sync failed"
        fi

        log "Done"
      ''}";
    };
  };

  # =========================================================================
  # Path unit — triggers the service when the current wallpaper changes
  #
  # Each shell writes ~/.local/share/current-wallpaper when the wallpaper
  # changes. This is the shell-agnostic handoff file:
  #   - Noctalia: set via hooks.wallpaperChange in settings.json (see
  #     modules/shells/noctalia/default.nix home.activation.noctaliaHooks)
  #   - Wayle: can be added as a post_hook in matugen config.toml if needed
  # =========================================================================
  systemd.user.paths.matugen = {
    Unit.Description = "Watch current-wallpaper file for wallpaper changes";
    Path.PathChanged  = "%h/.local/share/current-wallpaper";
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
    input_path = "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/colors.lua.template"
    output_path = "${config.home.homeDirectory}/.config/hypr/colors.lua"

    [templates.kitty]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/templates/kitty-colors.conf"
    output_path = "${config.home.homeDirectory}/.config/kitty/colors.conf"

    [templates.gtk]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/templates/gtk-colors.css"
    output_path = "${config.home.homeDirectory}/.config/gtk-4.0/colors.css.new"
    post_hook = "mv -f ${config.home.homeDirectory}/.config/gtk-4.0/colors.css.new ${config.home.homeDirectory}/.config/gtk-4.0/colors.css"

    [templates.gtk-libadwaita]
    input_path = "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/gtk-libadwaita.css.template"
    output_path = "${config.home.homeDirectory}/.config/gtk-4.0/libadwaita-matugen.css.new"
    post_hook = "mv -f ${config.home.homeDirectory}/.config/gtk-4.0/libadwaita-matugen.css.new ${config.home.homeDirectory}/.config/gtk-4.0/libadwaita-matugen.css"

    [templates.hyprlock]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/templates/hyprlock-colors.conf"
    output_path = "${config.home.homeDirectory}/.config/hypr/colors-hyprlock.conf"
  '';
}
