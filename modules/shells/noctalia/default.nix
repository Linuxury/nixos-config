# ===========================================================================
# modules/shells/noctalia/default.nix — Noctalia shell layer (v5+)
#
# Noctalia v5 is a full C++ rewrite of the v4 Quickshell/QML shell.
# Landed in nixpkgs as pkgs.noctalia — uses home-manager's own first-party
# programs.noctalia module (modules/programs/noctalia.nix upstream), not a
# dedicated flake input. package resolves to pkgs.noctalia automatically
# (mkPackageOption default) since useGlobalPkgs = true makes the pkgs HM
# modules see here the system's own instantiated nixpkgs.
#
# What this module sets up:
#   - programs.noctalia.enable     — installs the package
#   - programs.noctalia.systemd    — starts as a systemd user service;
#     upstream module wires graphical-session.target automatically
#     (replaces the v4 exec-once launch via shell-autostart.lua)
#   - programs.noctalia.settings   — declarative config.toml
#     wallpaper_changed hook writes ~/.local/share/current-wallpaper so
#     the matugen path unit (<compositor>/matugen/default.nix) fires as before
#   - notification daemon disabled — swaync handles notifications
#   - greeters/noctalia — noctalia-greeter (greetd), bundled automatically
#     so hosts don't need a separate greeter import. It matches the shell's
#     look natively; unlike wayle it does NOT need greeters/sddm.
#
# Theming split: Noctalia's own native app-theming (enabled via its
# settings.json, not Nix — see the activation block below) owns kitty, gtk,
# qt, starship, and umbriel's colors. matugen (still fired by the
# wallpaper_changed hook above) only covers what Noctalia has no template
# for: neovim, pywalfox, Kvantum. See this repo's theming docs / session
# history for why — Noctalia's patching model needs genuinely writable
# config files, which fought Nix's default immutable symlinks.
#
# Importing this module activates Noctalia (shell + greeter). No enable
# flag needed. To switch shell: remove this import, add shells/wayle
# (+ greeters/sddm).
# ===========================================================================

{ pkgs, ... }:

{
  imports = [ ../../greeters/noctalia/default.nix ];

  home-manager.sharedModules = [

    ({ lib, ... }: {
      programs.noctalia = {
        enable = true;

        # Systemd user service — replaces the v4 exec-once in shell-autostart.lua.
        # Noctalia's upstream module handles the graphical-session.target dependency
        # internally; we just enable the service here.
        systemd.enable = true;

        # Declarative config.toml — only the fields we need to override.
        # Everything else stays at noctalia defaults.
        settings = {
          # ── Wallpaper ──────────────────────────────────────────────────────
          # Point at the per-host wallpaper symlink that wallpaper-slideshow
          # manages. On wallpaper change, write the new path to the handoff
          # file that triggers the matugen path unit.
          wallpaper = {
            enabled   = true;
            directory = "~/Pictures/Wallpapers";
            automation = {
              enabled          = true;
              interval_minutes = 30;
              order            = "random";
              recursive        = true;
            };
          };

          # ── Theme ──────────────────────────────────────────────────────────
          # Derive accent colors from the active wallpaper so noctalia's own
          # bar colors stay in sync with the matugen palette.
          theme = {
            mode   = "dark";
            source = "wallpaper";
          };

          # ── Notification daemon ────────────────────────────────────────────
          # swaync handles notifications on this config — disable noctalia's
          # built-in daemon to avoid duplicate toasts.
          notification.enable_daemon = false;

          # ── Hooks ──────────────────────────────────────────────────────────
          # wallpaper_changed: write the new wallpaper path to the handoff
          # file that the matugen path unit (hyprland/matugen) watches.
          # $NOCTALIA_WALLPAPER_PATH is set by noctalia before running this.
          hooks.wallpaper_changed =
            ''echo "$NOCTALIA_WALLPAPER_PATH" > "$HOME/.local/share/current-wallpaper"'';
        };
      };
    })

    # =========================================================================
    # Clear shell-autostart.lua — v5 uses the systemd service above.
    # Clear shell-active.lua   — noctalia manages its own layer directly.
    # Both files are dofile()'d by hyprland.lua; empty = no-op.
    # =========================================================================
    ({ lib, ... }: {
      home.activation.noctaliaV5HyprFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        for _f in \
          "$HOME/nixos-config/dotfiles/hypr/shell-autostart.lua" \
          "$HOME/nixos-config/dotfiles/hypr/shell-active.lua"; do
          [ -d "$(dirname "$_f")" ] && : > "$_f"
        done
      '';

      # Noctalia v5 injects a [palettes.noctalia] block into starship.toml on
      # each wallpaper change. This used to fight a Nix-store symlink here
      # (chmod on a symlink target in /nix/store just fails silently) —
      # starship.toml is now deployed copy-once instead of symlinked (see
      # home.activation.starshipSeed in users/linuxury/home.nix), so it's a
      # genuine regular file Noctalia can patch directly. Nothing left to do
      # here.
    })

    # =========================================================================
    # Enable Noctalia's native "umbriel" app-theming template.
    #
    # Noctalia's own app-theming (kitty/gtk/qt/starship/etc.) is controlled
    # by ~/.config/noctalia/settings.json's templates.activeTemplates list —
    # a file Noctalia owns entirely at runtime, never Nix-managed. It already
    # had kitty/gtk/qt/starship enabled by hand well before Umbriel existed;
    # this just adds "umbriel" to that same list idempotently, so Umbriel's
    # own colors (border, accent) come from Noctalia instead of matugen too
    # (see modules/compositors/umbriel/matugen/default.nix).
    # =========================================================================
    ({ pkgs, lib, ... }: {
      home.activation.noctaliaEnableUmbrielTemplate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _sf="$HOME/.config/noctalia/settings.json"
        if [ -f "$_sf" ]; then
          if ! ${pkgs.jq}/bin/jq -e '.templates.activeTemplates[]? | select(.id == "umbriel")' "$_sf" >/dev/null 2>&1; then
            _tmp="$(mktemp)"
            ${pkgs.jq}/bin/jq '.templates.activeTemplates += [{"enabled": true, "id": "umbriel"}]' "$_sf" > "$_tmp" \
              && mv "$_tmp" "$_sf"
          fi
        fi
      '';
    })

  ];
}
