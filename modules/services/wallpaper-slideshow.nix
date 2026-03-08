# ===========================================================================
# modules/services/wallpaper-slideshow.nix — Wallpaper Slideshow + matugen
#
# Rotates wallpapers every 30 minutes and runs matugen on each change
# to keep the entire desktop theme in sync with the current wallpaper.
#
# How it works:
#   1. A systemd timer fires every 30 minutes
#   2. The service picks a random wallpaper from ~/Pictures/Wallpapers
#   3. Sets it via COSMIC's config file (ron format)
#   4. Runs matugen to regenerate all color themes from the new wallpaper
#   5. Each app's post-hook reloads with the new colors automatically
#
# ~/Pictures/Wallpapers is a symlink pointing at the right resolution
# folder from ~/assets/Wallpapers/ — set per host via home.nix argument.
#
# To disable on a specific host:
#   services.wallpaper-slideshow.enable = lib.mkForce false;
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  # =========================================================================
  # Required packages
  # =========================================================================
  home.packages = with pkgs; [
    matugen       # Material You color generator — themes entire desktop
    imagemagick   # dominant color extraction (workaround for matugen 4.x image bug)
    findutils     # find command for wallpaper discovery
    coreutils     # shuf for random selection
    git           # needed by matugenTemplates activation below
  ];

  # =========================================================================
  # matugen templates — clone from InioX/matugen-themes if not present
  #
  # matugen requires template files to render color schemes for each app.
  # We clone the community templates repo once on first activation.
  # Subsequent activations are a no-op (the directory already exists).
  #
  # Templates land in: ~/.config/matugen/templates/
  # Repo:              https://github.com/InioX/matugen-themes
  # =========================================================================
  home.activation.matugenTemplates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TEMPLATES_DIR="$HOME/.config/matugen/templates"
    if [ ! -d "$TEMPLATES_DIR" ]; then
      echo "matugen: cloning templates from InioX/matugen-themes…"
      ${pkgs.git}/bin/git clone --depth=1 \
        https://github.com/InioX/matugen-themes.git \
        "$TEMPLATES_DIR" \
        && echo "matugen: templates ready at $TEMPLATES_DIR" \
        || echo "matugen: WARNING — template clone failed (no internet?). Run manually:"$'\n'"  git clone https://github.com/InioX/matugen-themes ~/.config/matugen/templates"
    fi
  '';

  # =========================================================================
  # Ghostty colors seed file
  #
  # ghostty's config includes ~/.config/ghostty/colors via config-file.
  # matugen populates it on each wallpaper change, but if ghostty opens
  # before the first slideshow run the file won't exist yet.
  # We pre-create an empty file so ghostty always finds something to load.
  # =========================================================================
  home.activation.ghosttyColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    COLORS_FILE="$HOME/.config/ghostty/colors"
    if [ ! -f "$COLORS_FILE" ]; then
      mkdir -p "$(dirname "$COLORS_FILE")"
      touch "$COLORS_FILE"
      echo "matugen: created empty $COLORS_FILE (will be populated on first wallpaper change)"
    fi
  '';

  # =========================================================================
  # COSMIC accent template — written once, used by matugen on every run
  #
  # This is a custom template (not from InioX/matugen-themes) that outputs
  # the Material You primary color directly into COSMIC's accent config file.
  # COSMIC watches the file via inotify and picks up changes automatically.
  # =========================================================================
  home.activation.matugenCosmicAccentTemplate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ACCENT_TMPL="$HOME/.config/matugen/templates/cosmic-accent.ron"
    if [ ! -f "$ACCENT_TMPL" ]; then
      mkdir -p "$(dirname "$ACCENT_TMPL")"
      cat > "$ACCENT_TMPL" <<'RON'
(
    red: {{ colors.primary.default.red }},
    green: {{ colors.primary.default.green }},
    blue: {{ colors.primary.default.blue }},
    alpha: 1.0,
)
RON
    fi
  '';

  # =========================================================================
  # matugen config.toml — written at activation time if not present
  #
  # We use home.activation (shell script) instead of home.file.text to
  # avoid Nix evaluating the tilde paths inside the config content.
  # The config.toml is only written if it doesn't already exist so
  # manual edits are preserved across rebuilds.
  # =========================================================================
  home.activation.matugenConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    MATUGEN_CONF="$HOME/.config/matugen/config.toml"
    if [ ! -f "$MATUGEN_CONF" ]; then
      mkdir -p "$(dirname "$MATUGEN_CONF")"
      cat > "$MATUGEN_CONF" <<'TOML'
# ===========================================================
# matugen configuration
# Generates Material You color themes from wallpaper images
# Templates from: https://github.com/InioX/matugen-themes
# ===========================================================

[config]
mode = "dark"
reload_apps = true

[templates.ghostty]
input_path  = "~/.config/matugen/templates/templates/ghostty"
output_path = "~/.config/ghostty/colors"
post_hook   = "pkill -SIGUSR2 ghostty || true"

[templates.starship]
input_path  = "~/.config/matugen/templates/templates/starship-colors.toml"
output_path = "~/.config/starship-colors.toml"

[templates.gtk]
input_path  = "~/.config/matugen/templates/templates/gtk-colors.css"
output_path = "~/.config/gtk-4.0/colors.css"

[templates.cosmic]
input_path  = "~/.config/matugen/templates/templates/cosmic_theme.ron"
output_path = "~/.config/matugen/themes/matugen_cosmic.theme.ron"
post_hook   = "python3 ~/.config/matugen/templates/templates/cosmic_postprocess.py ~/.config/matugen/themes/matugen_cosmic.theme.ron"

[templates.cosmic-accent]
input_path  = "~/.config/matugen/templates/cosmic-accent.ron"
output_path = "~/.config/cosmic/com.system76.CosmicTheme.Dark/v1/accent"
post_hook   = "python3 ~/.config/matugen/templates/templates/cosmic_postprocess.py ~/.config/cosmic/com.system76.CosmicTheme.Dark/v1/accent"

[templates.dunst]
input_path  = "~/.config/matugen/templates/templates/dunstrc-colors"
output_path = "~/.config/dunst/dunstrc-colors"
post_hook   = "dunstctl reload || true"
TOML
    fi
  '';

  # =========================================================================
  # Wallpaper slideshow service
  #
  # Picks a random wallpaper, sets it in COSMIC, runs matugen.
  # COSMIC stores its wallpaper config in a ron file under
  # ~/.config/cosmic/com.system76.CosmicBackground/v1/
  # We write to it directly since there's no CLI tool yet.
  # =========================================================================
  systemd.user.services.wallpaper-slideshow = {
    Unit = {
      Description = "Wallpaper slideshow with matugen theme sync";
      After       = [ "graphical-session.target" ];
      Wants       = [ "graphical-session.target" ];
    };

    Service = {
      Type      = "oneshot";
      ExecStart = "${pkgs.writeShellScript "wallpaper-slideshow" ''
        #!/usr/bin/env bash
        set -euo pipefail

        WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
        COSMIC_BG_DIR="$HOME/.config/cosmic/com.system76.CosmicBackground/v1"
        LOG="$HOME/.local/share/wallpaper-slideshow.log"

        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
        }

        # ---------------------------------------------------------------
        # Pick a random wallpaper from ~/Pictures/Wallpapers
        # Supports jpg, jpeg, png, webp
        # ---------------------------------------------------------------
        WALLPAPER=$(find -L "$WALLPAPER_DIR" \
          -type f \
          \( -iname "*.jpg" -o -iname "*.jpeg" \
             -o -iname "*.png" -o -iname "*.webp" \) \
          | shuf -n 1)

        if [ -z "$WALLPAPER" ]; then
          log "ERROR: No wallpapers found in $WALLPAPER_DIR"
          exit 1
        fi

        log "Selected wallpaper: $WALLPAPER"

        # ---------------------------------------------------------------
        # Set wallpaper in COSMIC
        #
        # COSMIC stores wallpaper config as a ron file.
        # We write the same wallpaper for all outputs (monitors).
        # Format confirmed from COSMIC source and config inspection.
        # ---------------------------------------------------------------
        mkdir -p "$COSMIC_BG_DIR"

        cat > "$COSMIC_BG_DIR/all" <<RON
        (
            wallpapers: [
                (
                    output: "all",
                    source: File("$WALLPAPER"),
                    scaling_mode: Zoom,
                    sampling_method: Alphanumeric,
                )
            ],
        )
        RON

        log "COSMIC wallpaper config updated"

        # ---------------------------------------------------------------
        # Run matugen to regenerate all color themes
        #
        # matugen 4.x has a regression in its image reading path.
        # Workaround: extract the dominant color with ImageMagick first,
        # then feed the hex value to matugen color hex.
        # ---------------------------------------------------------------
        if command -v matugen &>/dev/null; then
          log "Extracting dominant color from $WALLPAPER"
          DOMINANT_HEX=$(convert "$WALLPAPER" -resize 1x1\! -format "%[hex:u]" info: 2>/dev/null)
          if [ -z "$DOMINANT_HEX" ]; then
            log "WARNING: ImageMagick failed to extract color, skipping theme generation"
          else
            log "Dominant color: #$DOMINANT_HEX — running matugen"
            matugen color hex "#$DOMINANT_HEX" >> "$LOG" 2>&1
            log "matugen complete"
          fi
        else
          log "WARNING: matugen not found, skipping theme generation"
        fi

        log "Done — next change in 30 minutes"
      ''}";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # =========================================================================
  # Wallpaper slideshow timer
  #
  # Fires immediately on session start (OnActiveSec=0) then every
  # 30 minutes after that. If the machine was off when a timer was
  # due it fires as soon as the session starts.
  # =========================================================================
  systemd.user.timers.wallpaper-slideshow = {
    Unit = {
      Description = "Wallpaper slideshow timer — every 30 minutes";
    };

    Timer = {
      OnActiveSec     = "0";
      OnUnitActiveSec = "30min";
      Persistent      = true;
      Unit            = "wallpaper-slideshow.service";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
