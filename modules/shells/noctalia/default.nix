# ===========================================================================
# modules/shells/noctalia/default.nix — Noctalia shell layer (v5+)
#
# Noctalia v5 is a full C++ rewrite of the v4 Quickshell/QML shell.
# Tracked via the noctalia flake input (not nixpkgs) so it isn't stuck behind
# nixpkgs' own packaging cadence. inputs.noctalia.homeModules.default disables
# home-manager's bundled programs/noctalia.nix module and points its package
# option at this input's own build instead.
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
# qt, umbriel's colors, pywalfox, and neovim (the last two via Noctalia's
# community-template catalog, same mechanism as the built-in ones).
# matugen (still fired by the wallpaper_changed hook above) covers what
# Noctalia has no template for (Kvantum) plus starship — starship used to
# be Noctalia-owned too, but that only worked on Hyprland/Umbriel; moved
# to matugen so it works identically on every compositor/DE (COSMIC
# included). See noctaliaDisableStarshipTemplate below and this repo's
# theming docs / session history for why — Noctalia's patching model needs
# genuinely writable config files, which fought Nix's default immutable
# symlinks.
#
# Importing this module activates Noctalia (shell + greeter). No enable
# flag needed. To switch shell: remove this import, add shells/wayle
# (+ greeters/sddm).
# ===========================================================================

{ inputs, pkgs, ... }:

{
  imports = [ ../../greeters/noctalia/default.nix ];

  home-manager.sharedModules = [

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

          # ── Screenshots ────────────────────────────────────────────────────
          # Native capture replaces the old grim/slurp/satty script. Every
          # other field (save_to_file, copy_to_clipboard, freeze_screen, ...)
          # already defaults to what that script did by hand.
          shell.screenshot.directory = "~/Pictures/Screenshots";

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

    })

    # =========================================================================
    # Disable Noctalia's own starship template — matugen now owns
    # ~/.config/starship.toml on every compositor/DE (see
    # modules/services/wallpaper-slideshow/default.nix). Without this,
    # Noctalia's live-patcher and matugen's post_hook would both overwrite
    # the same file on each wallpaper change and race unpredictably.
    # Idempotent: only edits settings.json if a "starship" entry is present.
    # =========================================================================
    ({ pkgs, lib, ... }: {
      home.activation.noctaliaDisableStarshipTemplate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _sf="$HOME/.config/noctalia/settings.json"
        if [ -f "$_sf" ] && ${pkgs.jq}/bin/jq -e \
            '.templates.activeTemplates[]? | select(.id == "starship")' "$_sf" >/dev/null 2>&1; then
          _tmp="$(mktemp)"
          ${pkgs.jq}/bin/jq \
            '.templates.activeTemplates |= map(select(.id != "starship"))' "$_sf" > "$_tmp" \
            && mv "$_tmp" "$_sf"
        fi
      '';
    })

    # =========================================================================
    # Enable Noctalia's native app-theming templates: umbriel (built-in),
    # pywalfox, neovim, and papirus-icons (community-catalog templates —
    # already fetched into ~/.local/state/noctalia/community-templates/ via
    # Settings -> Templates -> Browse Templates; this just flips them on).
    #
    # Noctalia's own app-theming is controlled by ~/.config/noctalia/
    # settings.json's templates.activeTemplates list — a file Noctalia owns
    # entirely at runtime, never Nix-managed. It already had kitty/gtk/qt/
    # starship enabled by hand well before Umbriel existed; this adds the
    # rest idempotently, one jq pass per ID, only touching the ones missing.
    # =========================================================================
    ({ pkgs, lib, ... }: {
      home.activation.noctaliaEnableTemplates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _sf="$HOME/.config/noctalia/settings.json"
        if [ -f "$_sf" ]; then
          for _id in umbriel pywalfox neovim papirus-icons; do
            if ! ${pkgs.jq}/bin/jq -e --arg id "$_id" \
                '.templates.activeTemplates[]? | select(.id == $id)' "$_sf" >/dev/null 2>&1; then
              _tmp="$(mktemp)"
              ${pkgs.jq}/bin/jq --arg id "$_id" \
                '.templates.activeTemplates += [{"enabled": true, "id": $id}]' "$_sf" > "$_tmp" \
                && mv "$_tmp" "$_sf"
            fi
          done
        fi
      '';
    })

    # =========================================================================
    # papirus-icons template's apply.sh assumes an FHS-style
    # /usr/share/icons/$variant install (to copy from before recoloring in a
    # writable dir, since Nix store paths are read-only) — that path doesn't
    # exist on NixOS, so it silently skips every variant. Point it at where
    # home-manager's icon theme package actually lands instead. Naturally
    # idempotent: after the first patch the old path string is gone, so
    # re-running this is a no-op.
    # =========================================================================
    ({ pkgs, lib, ... }: {
      home.activation.noctaliaPapirusIconsNixPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _af="$HOME/.local/state/noctalia/community-templates/papirus-icons/apply.sh"
        [ -f "$_af" ] && ${pkgs.gnused}/bin/sed -i \
          "s#/usr/share/icons#/etc/profiles/per-user/linuxury/share/icons#g" "$_af"
      '';
    })

  ];
}
