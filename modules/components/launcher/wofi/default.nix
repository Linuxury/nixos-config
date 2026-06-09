# ===========================================================================
# modules/components/launcher/wofi/default.nix — Wofi application launcher
#
# Compositor-agnostic application launcher.
# Works on any Wayland compositor.
#
# When imported, this module:
#   1. Adds wofi and rofi-wayland to system packages.
#   2. Symlinks dotfiles/wofi/ → ~/.config/wofi/  (all users)
#              dotfiles/rofi/ → ~/.config/rofi/  (all users)
#   3. If Hyprland is present: writes ~/.config/hypr/components/launcher.lua
#      - Launcher keybinds (SUPER+Space, SUPER+R)
#      - Clipboard history picker (SUPER+V via cliphist + wofi)
#      - Window switcher (SUPER+Tab via rofi)
#      - Wofi window rules (float, center, rounding)
#      Skipped on all other compositors — this module itself is compositor-agnostic.
# ===========================================================================

{ pkgs, ... }:

{
  config = {
    environment.systemPackages = with pkgs; [ wofi rofi-wayland ];

    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        home.file.".config/wofi".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/wofi";
        home.file.".config/rofi".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/rofi";

        home.activation.launcherHyprConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Only run on Hyprland hosts — skip silently on all others
          [ -d "$HOME/.config/hypr" ] || exit 0
          _target="$HOME/.config/hypr/components/launcher.lua"
          [ -d "$(dirname "$_target")" ] || mkdir -p "$(dirname "$_target")"
          printf '%s\n' \
            'local mod = "SUPER"' \
            '' \
            '-- ── Launcher ────────────────────────────────────────────────────────────' \
            'hl.bind(mod .. " + Space", hl.dsp.exec_cmd("wofi --show drun --normal-window"))' \
            'hl.bind(mod .. " + R",     hl.dsp.exec_cmd("wofi --show run --normal-window"))' \
            '' \
            '-- ── Clipboard history (cliphist + wofi) ────────────────────────────────' \
            'hl.bind(mod .. " + V", hl.dsp.exec_cmd(' \
            '    "cliphist list | wofi --dmenu --normal-window --style ~/.config/wofi/style.css | cliphist decode | wl-copy"' \
            '))' \
            '' \
            '-- ── Window switcher (rofi) ──────────────────────────────────────────────' \
            'hl.bind(mod .. " + Tab", hl.dsp.exec_cmd("rofi -show window -theme ~/.config/rofi/window.rasi"))' \
            '' \
            '-- ── Wofi window rules ───────────────────────────────────────────────────' \
            'hl.window_rule({ match = { class = "wofi" }, float    = true  })' \
            'hl.window_rule({ match = { class = "wofi" }, center   = true  })' \
            'hl.window_rule({ match = { class = "wofi" }, rounding = 10    })' \
            > "$_target"
        '';
      })
    ];
  };
}
