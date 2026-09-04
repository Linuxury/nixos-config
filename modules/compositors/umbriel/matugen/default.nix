# ===========================================================================
# modules/compositors/umbriel/matugen/default.nix — matugen color sync
#
# Scoped down to only the apps Noctalia's own native app-theming has no
# template for: neovim, pywalfox, Kvantum (confirmed by reading Noctalia's
# installed template list — no kvantum/neovim/pywalfox entries). Everything
# else Noctalia can theme (kitty, gtk, qt, starship, umbriel's own colors)
# is handled by Noctalia directly now — see modules/shells/noctalia/
# default.nix for how that's enabled and why matugen used to fight it.
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
# run — run 3× to ensure full coverage (same workaround as Hyprland's module).
# ===========================================================================
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    matugen
    imagemagick
  ];

  systemd.user.services.matugen = {
    Unit = {
      Description = "Apply matugen color theme for current Umbriel wallpaper";
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

        # Merge the pywalfox color template with the wallpaper path into
        # the file pywalfox actually reads. Key order in the source JSON
        # is load-bearing — pywalfox indexes colors positionally
        # (color0..color15), not by key name — never pipe this through
        # anything that sorts keys (e.g. jq -S).
        mkdir -p "$HOME/.cache/wal"
        if [ -f "$HOME/.cache/matugen/pywal-colors-raw.json" ]; then
          ${pkgs.jq}/bin/jq --arg wallpaper "$WALLPAPER" '{wallpaper: $wallpaper, colors: .}' \
            "$HOME/.cache/matugen/pywal-colors-raw.json" > "$HOME/.cache/wal/colors.json" \
            && log "pywal colors synced" || log "WARN pywal colors sync failed"
        fi

        # Umbriel applies config.toml + its [include] files live on write —
        # no reload command needed (unlike Hyprland's `hyprctl reload`).

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

    [templates.neovim]
    input_path = "${config.home.homeDirectory}/nixos-config/dotfiles/nvim/matugen/colors.lua.template"
    output_path = "${config.home.homeDirectory}/.local/share/nvim/lua/matugen-colors.lua"

    [templates.kvantum-kvconfig]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/templates/kvantum-colors.kvconfig"
    output_path = "${config.home.homeDirectory}/.config/Kvantum/kvantum-colors/kvantum-colors.kvconfig"

    [templates.kvantum-svg]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/templates/kvantum-colors.svg"
    output_path = "${config.home.homeDirectory}/.config/Kvantum/kvantum-colors/kvantum-colors.svg"

    # Feeds pywalfox's color source, merged with the wallpaper path into
    # ~/.cache/wal/colors.json by the jq step above. Reuses kitty's own
    # color0-15 mapping.
    [templates.pywalfox]
    input_path = "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/pywalfox-colors.json.template"
    output_path = "${config.home.homeDirectory}/.cache/matugen/pywal-colors-raw.json"
  '';
}
