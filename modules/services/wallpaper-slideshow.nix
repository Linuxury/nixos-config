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
    findutils     # find command for wallpaper discovery
    coreutils     # shuf for random selection
  ];

  # =========================================================================
  # matugen configuration — written at activation time
  #
  # We use home.activation (shell script) instead of home.file.text to
  # avoid Nix evaluating the tilde paths inside the config content.
  # The config.toml is written only if it doesn't already exist so
  # manual edits (e.g. adding WM templates) are preserved.
  #
  # Templates are NOT managed by Nix — clone matugen-themes manually:
  #   git clone https://github.com/InioX/matugen-themes \
  #     ~/.config/matugen/templates
  # See docs/manual-steps.md for the full setup sequence.
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
input_path  = "~/.config/matugen/templates/ghostty.conf"
output_path = "~/.config/ghostty/colors"
post_hook   = "pkill -SIGUSR2 ghostty || true"

[templates.starship]
input_path  = "~/.config/matugen/templates/starship.toml"
output_path = "~/.config/starship-colors.toml"

[templates.helix]
input_path  = "~/.config/matugen/templates/helix.toml"
output_path = "~/.config/helix/themes/matugen.toml"

[templates.gtk3]
input_path  = "~/.config/matugen/templates/gtk3.css"
output_path = "~/.config/gtk-3.0/colors.css"
post_hook   = "gsettings set org.gnome.desktop.interface gtk-theme '' || true"

[templates.gtk4]
input_path  = "~/.config/matugen/templates/gtk4.css"
output_path = "~/.config/gtk-4.0/colors.css"

[templates.cosmic]
input_path  = "~/.config/matugen/templates/cosmic_theme.ron"
output_path = "~/.config/matugen/themes/matugen_cosmic.theme.ron"
post_hook   = "python3 ~/.config/matugen/templates/cosmic_postprocess.py ~/.config/matugen/themes/matugen_cosmic.theme.ron"

[templates.dunst]
input_path  = "~/.config/matugen/templates/dunst.ini"
output_path = "~/.config/dunst/dunstrc"
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
    description = "Wallpaper slideshow with matugen theme sync";

    after    = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];

    serviceConfig = {
      Type      = "oneshot";
      ExecStart = pkgs.writeShellScript "wallpaper-slideshow" ''
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
        WALLPAPER=$(find "$WALLPAPER_DIR" \
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
        # from the new wallpaper image
        # ---------------------------------------------------------------
        if command -v matugen &>/dev/null; then
          log "Running matugen on $WALLPAPER"
          matugen image "$WALLPAPER" >> "$LOG" 2>&1
          log "matugen complete"
        else
          log "WARNING: matugen not found, skipping theme generation"
        fi

        log "Done — next change in 30 minutes"
      '';
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
    description = "Wallpaper slideshow timer — every 30 minutes";

    wantedBy = [ "timers.target" ];

    timerConfig = {
      # Fire immediately when session starts
      OnActiveSec = "0";
      # Then every 30 minutes
      OnUnitActiveSec = "30min";
      # If missed (machine was off) fire immediately on next session
      Persistent = true;
      Unit = "wallpaper-slideshow.service";
    };
  };
}
