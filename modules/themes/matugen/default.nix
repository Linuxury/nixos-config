# ===========================================================================
# modules/themes/matugen/default.nix — matugen color sync (Kvantum only)
#
# Trimmed down to Kvantum — the one remaining app with no Noctalia native
# theming template (confirmed by reading Noctalia's installed + community
# template lists: no kvantum entry anywhere). Everything else that used to
# live here (kitty, gtk, qt, starship, neovim, pywalfox, umbriel's own
# colors) is handled by Noctalia's own app-theming now — see
# modules/shells/noctalia/default.nix for how that's enabled.
#
# Moved out of modules/compositors/umbriel/ — Kvantum theming has nothing
# to do with which compositor is running, it was only nested under Umbriel
# by historical accident (copied from Hyprland's original matugen module).
# Import this from any compositor module that wants Kvantum theming.
#
# Shell-agnostic color sync. Works with any shell that writes the two
# handoff files below when the wallpaper changes:
#
#   ~/.local/share/current-wallpaper       — path to the active wallpaper
#   ~/.local/share/current-wallpaper-color — dominant color hint (optional)
#
# Path unit watches current-wallpaper. If a color hint file exists, it is
# used as the matugen input; otherwise ImageMagick extracts the dominant
# color as a fallback.
#
# matugen 4.0.0 HashMap iteration bug: crashes after 2–3 of 5 templates per
# run — run 3× to ensure full coverage.
# ===========================================================================
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    matugen
    imagemagick
  ];

  systemd.user.services.matugen = {
    Unit = {
      Description = "Apply matugen color theme (Kvantum) for current wallpaper";
      After       = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type        = "oneshot";
      ExecStart   = "${pkgs.writeShellScript "matugen" ''
        PROC_FILE="$HOME/.local/share/last-matugen-processed"
        LOG="$HOME/.local/share/wallpaper-service.log"
        CURRENT_WALLPAPER_FILE="$HOME/.local/share/current-wallpaper"
        COLOR_HINT="$HOME/.local/share/current-wallpaper-color"
        SDDM_WALLPAPER="/var/lib/sddm-wallpaper/background.jpg"

        log() { echo "[$(date "+%H:%M:%S")] MATUGEN $*" >> "$LOG"; }

        WALLPAPER=$(cat "$CURRENT_WALLPAPER_FILE" 2>/dev/null | tr -d '\n')
        if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
          log "No current wallpaper (''${CURRENT_WALLPAPER_FILE} empty or target missing)"
          exit 0
        fi

        # Deduplication — skip if this wallpaper's colors are already applied.
        KVANTUM_COLORS="$HOME/.config/Kvantum/kvantum-colors/kvantum-colors.kvconfig"
        LAST_PROC=$(cat "$PROC_FILE" 2>/dev/null || echo "")
        if [ -n "$LAST_PROC" ] && [ "$WALLPAPER" = "$LAST_PROC" ] && [ -f "$KVANTUM_COLORS" ]; then
          exit 0
        fi
        echo "$WALLPAPER" > "$PROC_FILE"

        log "Applying: $(basename "$WALLPAPER")"

        # Prefer the shell-provided color hint. Fall back to ImageMagick
        # dominant-color extraction for shells that only write current-wallpaper.
        HEX=""
        if [ -f "$COLOR_HINT" ]; then
          _hint=$(cat "$COLOR_HINT" | tr -d '[:space:]')
          case "$_hint" in
            \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
              HEX="$_hint"
              log "Color: $HEX (hint)" ;;
          esac
        fi
        if [ -z "$HEX" ]; then
          HEX=$(${pkgs.imagemagick}/bin/convert "$WALLPAPER" -resize 1x1 txt:- 2>/dev/null \
            | grep -oP "#[0-9A-Fa-f]{6}" | head -1)
          if [ -z "$HEX" ]; then log "WARN no color from $(basename "$WALLPAPER")"; exit 0; fi
          log "Color: $HEX (ImageMagick)"
        fi

        # matugen 4.0.0 has a HashMap iteration bug: it crashes after processing
        # only 2–3 of 5 templates per run. Running 3× ensures full coverage.
        ${pkgs.matugen}/bin/matugen color hex "$HEX" >> "$LOG" 2>&1 || true
        ${pkgs.matugen}/bin/matugen color hex "$HEX" >> "$LOG" 2>&1 || true
        ${pkgs.matugen}/bin/matugen color hex "$HEX" >> "$LOG" 2>&1 || true

        if [ -d "$(dirname "$SDDM_WALLPAPER")" ]; then
          cp "$WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null \
            && log "SDDM wallpaper synced: $(basename "$WALLPAPER")" \
            || log "WARN SDDM wallpaper sync failed"
        fi

        log "Done"
      ''}";
    };
  };

  systemd.user.paths.matugen = {
    Unit.Description = "Watch current-wallpaper for wallpaper changes";
    Path.PathChanged = "%h/.local/share/current-wallpaper";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Fires 10s after session start so the shell has time to set the initial
  # wallpaper and write current-wallpaper before we read it.
  systemd.user.timers.matugen = {
    Unit.Description = "Apply matugen colors on session start";
    Timer.OnActiveSec = "10s";
    Install.WantedBy  = [ "graphical-session.target" ];
  };

  home.file.".config/matugen/config.toml".text = ''
    [config]
    mode = "dark"
    reload_apps = false

    [templates.kvantum-kvconfig]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/templates/kvantum-colors.kvconfig"
    output_path = "${config.home.homeDirectory}/.config/Kvantum/kvantum-colors/kvantum-colors.kvconfig"

    [templates.kvantum-svg]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/templates/kvantum-colors.svg"
    output_path = "${config.home.homeDirectory}/.config/Kvantum/kvantum-colors/kvantum-colors.svg"
  '';
}
