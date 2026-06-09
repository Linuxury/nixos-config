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
#   3. Writes ~/.config/hypr/components/launcher.lua at HM activation:
#      - Launcher keybinds (SUPER+Space, SUPER+R)
#      - Clipboard history picker (SUPER+V via cliphist + wofi)
#      - Window switcher (SUPER+Tab via rofi)
#      - Wofi window rules (float, center, rounding)
#      The file is only loaded when Hyprland is the active compositor.
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
          _target="$HOME/.config/hypr/components/launcher.lua"
          _dir="$(dirname "$_target")"
          [ -d "$_dir" ] || mkdir -p "$_dir"
          [ -d "$HOME/.config/hypr" ] || exit 0
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
