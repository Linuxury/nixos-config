# ===========================================================================
# modules/components/notifications/swaync/default.nix — SwayNC notification daemon
#
# Compositor-agnostic notification daemon with a slide-in control center.
# Works on any wlr-layer-shell compositor (Hyprland, Niri, Sway…).
#
# When imported, this module:
#   1. Adds swaync to system packages.
#   2. Injects hm.nix into every user via home-manager.sharedModules,
#      which generates ~/.config/swaync/config.json from host options.
#   3. If Hyprland is present: writes ~/.config/hypr/components/notifications.lua
#      (layer rules for the slide-in animation). Skipped on all other
#      compositors — this module itself is compositor-agnostic.
#
# Set these options in your host config (hosts/<name>/default.nix):
#   myModules.swaync.hasBacklight      = true;
#   myModules.swaync.backlightDevice   = "amdgpu_bl1";  # ls /sys/class/backlight/
#   myModules.swaync.hasKbBacklight    = true;
#   myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";
#   myModules.swaync.hasWifi           = true;   # default true
#   myModules.swaync.hasBluetooth      = true;   # default true
# ===========================================================================

{ pkgs, lib, ... }:

{
  options.myModules.swaync = {
    hasBacklight = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Whether this host has a display backlight (laptop screen).";
    };

    backlightDevice = lib.mkOption {
      type    = lib.types.str;
      default = "";
      description = "Backlight device name (ls /sys/class/backlight/).";
    };

    hasKbBacklight = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Whether this host has keyboard backlight LEDs.";
    };

    kbBacklightDevice = lib.mkOption {
      type    = lib.types.str;
      default = "";
      description = "Keyboard backlight LED device name (ls /sys/class/leds/).";
    };

    hasWifi = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Whether to show WiFi toggle in SwayNC control panel.";
    };

    hasBluetooth = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Whether to show Bluetooth toggle in SwayNC control panel.";
    };
  };

  config = {
    environment.systemPackages = [ pkgs.swaynotificationcenter ];

    home-manager.sharedModules = [
      # Generate ~/.config/swaync/config.json from host options.
      ./hm.nix

      # If Hyprland is present: write layer rules for the swaync slide animation.
      # Skipped silently on all other compositors.
      ({ lib, ... }: {
        home.activation.swayncHyprRules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Only run on Hyprland hosts — skip silently on all others
          [ -d "$HOME/.config/hypr" ] || exit 0
          _target="$HOME/.config/hypr/components/notifications.lua"
          [ -d "$(dirname "$_target")" ] || mkdir -p "$(dirname "$_target")"
          printf '%s\n' \
            '-- swaync layer rules — slide in from the right' \
            'hl.layer_rule({ match = { namespace = "swaync/control-center"      }, animation = "slide right" })' \
            'hl.layer_rule({ match = { namespace = "swaync/notification-window" }, animation = "slide right" })' \
            > "$_target"
        '';
      })
    ];
  };
}
