# ===========================================================================
# modules/shells/noctalia/default.nix — Noctalia shell layer (v5+)
#
# Noctalia v5 is a full C++ rewrite of the v4 Quickshell/QML shell.
# The upstream flake (inputs.noctalia) provides homeModules.default with
# a first-class programs.noctalia HM module.
#
# What this module sets up:
#   - programs.noctalia.enable     — installs the package
#   - programs.noctalia.systemd    — starts as a systemd user service;
#     upstream module wires graphical-session.target automatically
#     (replaces the v4 exec-once launch via shell-autostart.lua)
#   - programs.noctalia.settings   — declarative config.toml
#     wallpaper_changed hook writes ~/.local/share/current-wallpaper so
#     the matugen path unit (hyprland/matugen/default.nix) fires as before
#   - notification daemon disabled — swaync handles notifications
#   - greeters/noctalia — noctalia-greeter (greetd), bundled automatically
#     so hosts don't need a separate greeter import. It matches the shell's
#     look natively; unlike wayle it does NOT need greeters/sddm.
#
# matugen fires on every wallpaper change via the hook — it falls back to
# ImageMagick dominant-color extraction. Re-enable noctalia→matugen accent
# sync when v5's template output path is stable.
#
# Importing this module activates Noctalia (shell + greeter). No enable
# flag needed. To switch shell: remove this import, add shells/wayle
# (+ greeters/sddm).
# ===========================================================================

{ inputs, pkgs, ... }:

{
  imports = [ ../../greeters/noctalia/default.nix ];

  home-manager.sharedModules = [

    # =========================================================================
    # Noctalia v5 Home Manager module — from upstream flake
    #
    # homeModules.default wires programs.noctalia.package automatically to
    # inputs.noctalia.packages.${system}.default. All we do here is enable
    # the module and configure it.
    # =========================================================================
    inputs.noctalia.homeModules.default

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
      # each wallpaper change (assets/templates/builtin.toml + apply.sh).
      #
      # Two problems to solve:
      #   1. HM deploys starship.toml as read-only (444); sed -i renames it
      #      (bypasses 444 via directory perms) but the >> append still fails.
      #      Fix: chmod 644 after writeBoundary so the append succeeds.
      #   2. On the next HM switch, noctalia has already modified the file;
      #      HM refuses to overwrite ("would be clobbered"). Fix: force = true
      #      tells HM to always clobber regardless of current content.
      #
      # Cycle per switch: HM force-writes nord → activation makes it 644 →
      # noctalia re-applies noctalia palette on next wallpaper change. ✓
      home.file.".config/starship.toml".force = lib.mkForce true;

      home.activation.starshipWritableForNoctalia = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _sf="''${STARSHIP_CONFIG:-''${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"
        [ -f "$_sf" ] && chmod 644 "$_sf" || true
      '';
    })

  ];
}
