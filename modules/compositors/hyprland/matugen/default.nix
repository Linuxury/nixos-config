# ===========================================================================
# modules/compositors/hyprland/matugen/default.nix — matugen color sync
#
# Path unit watches ~/.config/noctalia/colors.json — written by Noctalia
# after it finishes its own material-color pass. Reading mPrimary from that
# file ensures matugen and Noctalia start from the same source color, keeping
# Hyprland borders in sync with the bar accent.
#
# current-wallpaper (written by the wallpaperChange hook before colors.json)
# is still used for deduplication and SDDM wallpaper sync.
#
# matugen 4.0.0 HashMap iteration bug: crashes after 2–3 of 5 templates per
# run — run 3× to ensure full coverage. hyprctl reload applies colors.lua.
# ===========================================================================
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    matugen
    jq
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
        NOCTALIA_COLORS="$HOME/.config/noctalia/colors.json"
        SDDM_WALLPAPER="/var/lib/sddm-wallpaper/background.jpg"

        log() { echo "[$(date "+%H:%M:%S")] MATUGEN $*" >> "$LOG"; }

        # Read wallpaper path for deduplication + SDDM sync.
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

        # Read mPrimary from Noctalia's colors.json — same source color Noctalia
        # uses for its bar accent, so borders and bar stay in sync.
        if [ ! -f "$NOCTALIA_COLORS" ]; then
          log "WARN colors.json missing, skipping"
          exit 0
        fi
        HEX=$(${pkgs.jq}/bin/jq -r '.mPrimary' "$NOCTALIA_COLORS")
        if [ -z "$HEX" ] || [ "$HEX" = "null" ]; then
          log "WARN no mPrimary in colors.json"
          exit 0
        fi

        log "Color: $HEX (from Noctalia)"

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
  # Path unit — triggers after Noctalia finishes its color pass
  #
  # Watching colors.json (not current-wallpaper) ensures the service fires
  # after Noctalia has written the new palette, so mPrimary is current.
  # current-wallpaper is written first by the wallpaperChange hook, so it
  # is always ready when this service runs.
  # =========================================================================
  systemd.user.paths.matugen = {
    Unit.Description  = "Watch Noctalia colors.json for wallpaper color changes";
    Path.PathModified = "%h/.config/noctalia/colors.json";
    Install.WantedBy  = [ "graphical-session.target" ];
  };

  # =========================================================================
  # Startup timer — ensures colors are applied at session start
  # Fires 10s after session start to let Noctalia finish its initial
  # wallpaper + color pass before the service reads colors.json.
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
