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
# Theming split: Noctalia's own templates own app theming (kitty, gtk, qt,
# starship, umbriel, pywalfox, thunderbird, papirus-icons, ...). Which ones
# are on is app state: Settings → Theme → Templates, saved to
# ~/.local/state/noctalia/settings.toml — not Nix. matugen
# (themes/matugen) only covers Kvantum, which has no Noctalia template.
# Templates need genuinely writable target files, so don't hand them
# HM-managed (read-only store) paths — that's why fastfetch's is off.
#
# Importing this module activates Noctalia (shell + greeter). No enable
# flag needed. To switch shell: remove this import, add shells/wayle
# (+ greeters/sddm).
# ===========================================================================

{ config, inputs, lib, pkgs, ... }:

let
  # Pushes the palette's primary color to OpenRGB devices + the Lemokey
  # keyboard. Only wired up on hosts with hardware.openrgb.enable.
  ledSync = pkgs.writeShellApplication {
    name = "led-sync";
    runtimeInputs = [ config.services.hardware.openrgb.package ] ++ (with pkgs; [ gawk gnugrep coreutils ]);
    text = builtins.readFile ./color-sync/led-sync.sh;
  };
in
{
  imports = [ ../../greeters/noctalia/default.nix ];

  # Thunderbird is themed by Noctalia's `thunderbird` template here. The
  # pywalfox add-on (force-installed by system/graphical/thunderbird for
  # matugen hosts) fought it over the toolbar colors; "blocked" uninstalls it.
  # No-op on hosts without Thunderbird.
  programs.thunderbird.policies.ExtensionSettings."pywalfox@frewacom.org".installation_mode =
    lib.mkForce "blocked";

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
              interval_seconds = 1800;
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
          } // lib.optionalAttrs config.hardware.openrgb.enable {
            # LED sync: render the bare primary hex, then push it to the
            # RGB hardware (see color-sync/led-sync.sh).
            templates.user.led-sync = {
              input_path  = "${pkgs.writeText "led-color" "{{colors.primary.default.hex_stripped}}"}";
              output_path = "$XDG_CACHE_HOME/noctalia/led-color";
              post_hook   = "${ledSync}/bin/led-sync";
            };
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
          # Lossless WebP (quality 100): smaller than PNG, same pixels.
          # Clipboard/pipe output stays PNG regardless.
          shell.screenshot.format  = "webp";
          shell.screenshot.quality = 100;

          # ── Umbriel ────────────────────────────────────────────────────────
          # Both no-ops on any other compositor (noctalia checks isUmbriel()).
          # Close the overview when an app is launched from it, and feed
          # Umbriel's audio-reactive effects from noctalia's PipeWire spectrum.
          shell.umbriel_overview_close_on_launch_enabled = true;
          shell.umbriel_audio_provider_enabled           = true;

          # ── Session panel ──────────────────────────────────────────────────
          # Noctalia's default five actions + reboot to UEFI firmware setup.
          # Declaring the list replaces the defaults, so all of them are
          # spelled out (shortcuts match upstream's 1–5). reboot_uefi refuses
          # to run (logs an error) on non-UEFI boots.
          shell.session.actions = [
            { action = "lock";             shortcut = "1"; }
            { action = "logout";           shortcut = "2"; }
            { action = "lock_and_suspend"; shortcut = "3"; }
            { action = "reboot";           shortcut = "4"; }
            { action = "shutdown";         shortcut = "5"; variant = "destructive"; }
            { action = "reboot_uefi";      shortcut = "6"; }
          ];

          # ── App launching ──────────────────────────────────────────────────
          # Run launcher/dock apps as their own app-*.service units instead of
          # children of noctalia.service — otherwise every home-manager restart
          # of noctalia (most nru runs) kills every app launched through it.
          shell.launch_apps_as_systemd_services = true;

          # ── Plugins ────────────────────────────────────────────────────────
          # Our own plugins, loaded straight from the repo (live path, so edits
          # hot-reload without a rebuild). nix-updates: bar badge + panel for
          # pending package updates. Its settings (flake dir, update command,
          # interval) are set once via Settings → Plugins → ⚙.
          # Declaring any source replaces Noctalia's built-in list, so official
          # and community must be listed here too. Don't add/remove sources via
          # IPC or the GUI: that saves a full source list to the app-owned
          # settings.toml, which then overrides this one.
          # nix-updates "Compare against": only Ryzen5900x updates flake inputs
          # (nru's lock-writer rule); every other host builds the lock it pulls,
          # so the plugin there compares against the remote lock — what the
          # next nru will really bring, with no GitHub API calls.
          plugin_settings."linuxury/nix-updates".compare =
            if config.networking.hostName == "Ryzen5900x" then "upstream" else "remote";

          plugins = {
            enabled = [ "linuxury/nix-updates" ];
            source  = [
              { name = "official";  kind = "git"; location = "https://github.com/noctalia-dev/official-plugins";  enabled = true; }
              { name = "community"; kind = "git"; location = "https://github.com/noctalia-dev/community-plugins"; enabled = true; }
              { name = "nixos-config"; kind = "path"; location = "~/nixos-config/dotfiles/noctalia/plugins"; enabled = true; }
            ];
          };

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

  ];
}
