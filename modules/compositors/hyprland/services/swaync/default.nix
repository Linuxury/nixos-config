# ===========================================================================
# modules/compositors/hyprland/services/swaync/default.nix
#
# NixOS-level module for SwayNC on Hyprland:
#   1. Declares options.myModules.swaync.* so hm.nix can read osConfig.
#   2. Injects hm.nix into home-manager.sharedModules so every user on this
#      host gets the SwayNC config.json built from these options.
#
# Set these options in your host config (hosts/<name>/default.nix):
#   myModules.swaync.hasBacklight      = true;
#   myModules.swaync.backlightDevice   = "amdgpu_bl1";  # ls /sys/class/backlight/
#   myModules.swaync.hasKbBacklight    = true;
#   myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";  # ls /sys/class/leds/
#   myModules.swaync.hasWifi           = true;   # default true
#   myModules.swaync.hasBluetooth      = true;   # default true
# ===========================================================================

{ lib, ... }:

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
    # Inject the HM swaync config into every user on this Hyprland host.
    home-manager.sharedModules = [ ./hm.nix ];
  };
}
