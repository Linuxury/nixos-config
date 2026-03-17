# ===========================================================================
# modules/services/wallpaper-slideshow.nix — matugen color sync
#
# COSMIC handles wallpaper rotation via its built-in slideshow.
# Set it up in COSMIC Settings > Desktop > Wallpaper.
#
# This module only handles the matugen side:
#   - Watches COSMIC's background config for any change
#   - Runs matugen to regenerate all color themes from the current wallpaper
#   - Each app's post-hook reloads with the new colors automatically
#
# Also runs matugen once on login via a timer so colors match the wallpaper
# that was active when you last closed the session.
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
    python3       # needed by matugen's COSMIC post-hook (cosmic_postprocess.py)
  ];

  # =========================================================================
  # matugen templates — clone from InioX/matugen-themes if not present
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
  # Seed files — pre-create empty color files so apps don't fail on first boot
  # =========================================================================
  home.activation.ghosttyColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    COLORS_FILE="$HOME/.config/ghostty/colors"
    if [ ! -f "$COLORS_FILE" ]; then
      mkdir -p "$(dirname "$COLORS_FILE")"
      touch "$COLORS_FILE"
    fi
  '';

  home.activation.kittyColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    COLORS_FILE="$HOME/.config/kitty/colors.conf"
    if [ ! -f "$COLORS_FILE" ]; then
      mkdir -p "$(dirname "$COLORS_FILE")"
      touch "$COLORS_FILE"
    fi
  '';

  # =========================================================================
  # Neovim matugen template
  # =========================================================================
  home.file.".config/matugen/neovim.lua" = {
    source = ../../dotfiles/nvim/templates/matugen.lua;
    force  = true;
  };

  # =========================================================================
  # matugen config.toml
  # =========================================================================
  home.file.".config/matugen/config.toml" = {
    force = true;
    text = ''
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
      post_hook   = "python3 ~/.config/matugen/templates/templates/cosmic_postprocess.py ~/.config/matugen/themes/matugen_cosmic.theme.ron && sed -i 's/alpha: 0\\.6,/alpha: 0.85,/' ~/.config/matugen/themes/matugen_cosmic.theme.ron && cosmic-settings appearance import ~/.config/matugen/themes/matugen_cosmic.theme.ron || true"

      [templates.dunst]
      input_path  = "~/.config/matugen/templates/templates/dunstrc-colors"
      output_path = "~/.config/dunst/dunstrc-colors"
      post_hook   = "dunstctl reload || true"

      [templates.kitty]
      input_path  = "~/.config/matugen/templates/templates/kitty-colors.conf"
      output_path = "~/.config/kitty/colors.conf"
      post_hook   = "pkill -USR1 kitty || true"

      [templates.btop]
      input_path  = "~/.config/matugen/templates/templates/btop.theme"
      output_path = "~/.config/btop/themes/matugen.theme"
      post_hook   = "mkdir -p ~/.config/btop/themes && sed -i 's/^color_theme = .*/color_theme = \"matugen\"/' ~/.config/btop/btop.conf 2>/dev/null || true"

      [templates.zed]
      input_path  = "~/.config/matugen/templates/templates/zed-colors.json"
      output_path = "~/.config/zed/themes/matugen.json"

      [templates.neovim]
      input_path  = "~/.config/matugen/neovim.lua"
      output_path = "~/.config/nvim/colors/matugen.lua"
    '';
  };

  # =========================================================================
  # Wallpaper color sync service
  #
  # Reads the current wallpaper from COSMIC's config and runs matugen.
  # Triggered by the path unit below (COSMIC config changed) and by the
  # timer below (on login / periodic catch-up for slideshow rotations).
  # =========================================================================
  systemd.user.services.wallpaper-color-sync = {
    Unit = {
      Description = "Sync matugen colors with current COSMIC wallpaper";
      After       = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type        = "oneshot";
      Environment = [
        "SHELL=/bin/sh"
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin:/usr/bin:/bin"
      ];
      ExecStart = "${pkgs.writeShellScript "wallpaper-color-sync" ''
        #!/usr/bin/env bash
        set -euo pipefail

        COSMIC_BG_DIR="$HOME/.config/cosmic/com.system76.CosmicBackground/v1"
        LOG="$HOME/.local/share/wallpaper-slideshow.log"

        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
        }

        # ---------------------------------------------------------------
        # Read current wallpaper from COSMIC config.
        # Checks per-output files (DP-3, HDMI-A-1, etc.) first,
        # then falls back to the "all" file.
        # ---------------------------------------------------------------
        COSMIC_BG_CONF=$(find "$COSMIC_BG_DIR" -maxdepth 1 -type f \
          ! -name "same-on-all" ! -name "all" ! -name "backgrounds" | head -1)
        if [ -z "$COSMIC_BG_CONF" ]; then
          COSMIC_BG_CONF="$COSMIC_BG_DIR/all"
        fi

        WALLPAPER=$(grep -oP '(?:File|Path)\("\K[^"]+' "$COSMIC_BG_CONF" | head -1)

        if [ -z "$WALLPAPER" ]; then
          log "ERROR: Could not parse wallpaper from $COSMIC_BG_CONF"
          exit 1
        fi

        # If source is a directory, pick a random image from it
        if [ -d "$WALLPAPER" ]; then
          WALLPAPER=$(find -L "$WALLPAPER" -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" \
               -o -iname "*.png" -o -iname "*.webp" \) \
            | shuf -n 1)
        fi

        if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
          log "ERROR: Could not find a usable wallpaper file"
          exit 1
        fi

        # Skip if wallpaper hasn't changed since last matugen run.
        # Prevents a feedback loop: matugen → COSMIC theme update →
        # cosmic-bg config rewrite (filter_by_theme) → path watcher fires → repeat.
        LAST_FILE="$HOME/.local/share/last-matugen-wallpaper"
        LAST=$(cat "$LAST_FILE" 2>/dev/null || echo "")
        if [ "$WALLPAPER" = "$LAST" ]; then
          exit 0
        fi
        echo "$WALLPAPER" > "$LAST_FILE"

        if ! command -v matugen &>/dev/null; then
          log "WARNING: matugen not found, skipping"
          exit 0
        fi

        log "Color sync — wallpaper: $WALLPAPER"
        DOMINANT_HEX=$(convert "$WALLPAPER" -resize 1x1\! -format "%[hex:u]" info: 2>/dev/null)

        if [ -z "$DOMINANT_HEX" ]; then
          log "WARNING: ImageMagick failed, skipping"
          exit 0
        fi

        log "Dominant color: #$DOMINANT_HEX — running matugen"
        matugen color hex "#$DOMINANT_HEX" >> "$LOG" 2>&1
        log "matugen complete"
      ''}";
    };
  };

  # =========================================================================
  # Path watcher — fires color sync when COSMIC changes the wallpaper
  # (covers both manual changes in COSMIC settings and slideshow rotations
  #  that write a new File(...) to the config)
  # =========================================================================
  systemd.user.paths.wallpaper-color-sync = {
    Unit = {
      Description = "Watch COSMIC wallpaper config for changes";
    };

    Path = {
      PathChanged = "%h/.config/cosmic/com.system76.CosmicBackground/v1";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # =========================================================================
  # Timer — runs color sync on login and periodically
  #
  # Catches wallpaper changes that don't trigger a config file write
  # (e.g. COSMIC's internal slideshow rotation using source: Path(dir)).
  # Fires once on login, then every 10 minutes to stay in sync.
  # =========================================================================
  systemd.user.timers.wallpaper-color-sync = {
    Unit = {
      Description = "Periodic matugen color sync";
    };

    Timer = {
      OnBootSec        = "30s";
      OnUnitActiveSec  = "10min";
      Persistent       = true;
      Unit             = "wallpaper-color-sync.service";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
