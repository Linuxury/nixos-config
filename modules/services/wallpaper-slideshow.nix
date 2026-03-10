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
    python3       # needed by matugen's COSMIC post-hook (cosmic_postprocess.py)
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
  # matugen config.toml — managed declaratively by Home Manager
  #
  # force = true ensures stale configs (wrong template paths, old layout)
  # are always replaced on rebuild. Every COSMIC user stays in sync.
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
    '';
  };

  # =========================================================================
  # Wallpaper slideshow service
  #
  # Picks a random wallpaper and sets it in COSMIC's config file.
  # Color theme sync is handled separately by wallpaper-color-sync.service,
  # which is triggered by wallpaper-color-sync.path whenever the COSMIC
  # background config changes — covering both our rotation and manual
  # wallpaper changes made through COSMIC's settings.
  # =========================================================================
  systemd.user.services.wallpaper-slideshow = {
    Unit = {
      Description = "Wallpaper slideshow — picks a random wallpaper";
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
        # If COSMIC is already using its own slideshow (source: Path(dir)),
        # skip overwriting — its rotation takes precedence.
        # Writing this file triggers wallpaper-color-sync.path, which
        # runs matugen to regenerate all color themes automatically.
        # ---------------------------------------------------------------
        mkdir -p "$COSMIC_BG_DIR"

        CURRENT_SOURCE=$(grep -oP '(?:File|Path)\("\K[^"]+' "$COSMIC_BG_DIR/all" 2>/dev/null | head -1)
        if [ -d "$CURRENT_SOURCE" ]; then
          log "COSMIC slideshow is active — skipping wallpaper write, triggering color sync directly"
          systemctl --user start wallpaper-color-sync.service
        else
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
          log "COSMIC wallpaper config updated — color sync will follow"
        fi
      ''}";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # =========================================================================
  # Wallpaper color sync service
  #
  # Reads the currently active wallpaper from COSMIC's config and runs
  # matugen to regenerate all color themes. Triggered by the path unit
  # below whenever the COSMIC background config changes — this covers
  # both our 30-minute rotation and manual wallpaper changes in COSMIC.
  #
  # matugen 4.x has a regression in its image reading path.
  # Workaround: extract the dominant color with ImageMagick first,
  # then feed the hex value to matugen color hex.
  # =========================================================================
  systemd.user.services.wallpaper-color-sync = {
    Unit = {
      Description = "Sync matugen colors with current COSMIC wallpaper";
      After       = [ "graphical-session.target" ];
      # Disable rate limiting — cosmic-settings appearance import triggers COSMIC to
      # rewrite its config, which re-fires the path watcher. The service exits fast
      # and cleanly so rapid retriggers are harmless.
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type        = "oneshot";
      # Include nix profile and system bins so matugen post-hooks (python3, etc.) work
      Environment = "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin:/usr/bin:/bin";
      ExecStart = "${pkgs.writeShellScript "wallpaper-color-sync" ''
        #!/usr/bin/env bash
        set -euo pipefail

        COSMIC_BG_CONF="$HOME/.config/cosmic/com.system76.CosmicBackground/v1/all"
        LOG="$HOME/.local/share/wallpaper-slideshow.log"

        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
        }

        # ---------------------------------------------------------------
        # Read current wallpaper from COSMIC config
        # Handles both File("...") and Path("...") RON variants.
        # If source is a directory (COSMIC slideshow mode), pick a
        # random file from it — colors stay in sync with the collection.
        # ---------------------------------------------------------------
        WALLPAPER=$(grep -oP '(?:File|Path)\("\K[^"]+' "$COSMIC_BG_CONF" | head -1)

        if [ -z "$WALLPAPER" ]; then
          log "ERROR: Could not parse wallpaper source from $COSMIC_BG_CONF"
          exit 1
        fi

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

        if ! command -v matugen &>/dev/null; then
          log "WARNING: matugen not found, skipping theme generation"
          exit 0
        fi

        log "Color sync triggered — wallpaper: $WALLPAPER"
        DOMINANT_HEX=$(convert "$WALLPAPER" -resize 1x1\! -format "%[hex:u]" info: 2>/dev/null)

        if [ -z "$DOMINANT_HEX" ]; then
          log "WARNING: ImageMagick failed to extract color, skipping theme generation"
          exit 0
        fi

        log "Dominant color: #$DOMINANT_HEX — running matugen"
        matugen color hex "#$DOMINANT_HEX" >> "$LOG" 2>&1
        log "matugen complete"
      ''}";
    };
  };

  # =========================================================================
  # Wallpaper color sync path unit
  #
  # Watches COSMIC's background config file for any change.
  # Fires whether the change came from our slideshow service or from
  # the user changing the wallpaper manually in COSMIC settings.
  # =========================================================================
  systemd.user.paths.wallpaper-color-sync = {
    Unit = {
      Description = "Watch COSMIC wallpaper config for changes";
    };

    Path = {
      PathChanged = "%h/.config/cosmic/com.system76.CosmicBackground/v1/all";
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
