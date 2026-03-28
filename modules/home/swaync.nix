# ===========================================================================
# modules/home/swaync.nix — SwayNC Control Panel (Home Manager module)
#
# Generates config.json dynamically based on host hardware capabilities
# declared via NixOS options (options.myModules.swaync.*) in hyprland.nix.
#
# Host option reference (set in hosts/<name>/default.nix):
#   myModules.swaync.hasBacklight      = true;
#   myModules.swaync.backlightDevice   = "amdgpu_bl1";  # ls /sys/class/backlight/
#   myModules.swaync.hasKbBacklight    = true;
#   myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";  # ls /sys/class/leds/
#   myModules.swaync.hasWifi           = true;   # default true
#   myModules.swaync.hasBluetooth      = true;   # default true
#
# Widget layout (panel top → bottom):
#   title → dnd → backlight#display (laptop) → backlight#kbd (laptop)
#   → volume (+ expandable per-app) → buttons-grid (WiFi, BT) → mpris → notifications
# ===========================================================================

{ config, pkgs, lib, osConfig, ... }:

let
  cfg = osConfig.myModules.swaync;

  # Whether there are any buttons to show in the grid
  hasButtons = cfg.hasWifi || cfg.hasBluetooth;

  # Dynamic widget list — host-capability-aware
  widgets =
    [ "title" "dnd" ]
    ++ lib.optionals cfg.hasBacklight  [ "backlight#display" ]
    ++ lib.optionals cfg.hasKbBacklight [ "backlight#kbd" ]
    ++ [ "volume" ]
    ++ lib.optionals hasButtons [ "buttons-grid" ]
    ++ [ "mpris" "notifications" ];

  # Toggle button actions — only include the hardware that exists
  buttonActions =
    lib.optionals cfg.hasWifi [{
      label    = "󰖩  WiFi";
      command  = "sh -c 'if nmcli radio wifi 2>/dev/null | grep -q enabled; then nmcli radio wifi off; else nmcli radio wifi on; fi'";
    }]
    ++ lib.optionals cfg.hasBluetooth [{
      label    = "󰂯  BT";
      command  = "sh -c 'if bluetoothctl show 2>/dev/null | grep -q \"Powered: yes\"; then bluetoothctl power off; else bluetoothctl power on; fi'";
    }];

  # Per-widget configuration
  widgetConfig =
    {
      title = {
        text             = "Control Panel";
        clear-all-button = true;
        button-text      = "Clear All";
      };
      dnd = {
        text = "Do Not Disturb";
      };
      volume = {
        label                  = "󰕾";
        show-per-app           = true;
        expand-per-app         = false;             # collapsed by default
        empty-list-label       = "No active apps";
        expand-button-label    = "󰐕  Apps";
        collapse-button-label  = "󰐊  Collapse";
      };
      mpris = {
        image-size   = 80;
        image-radius = 8;
        autohide     = true;   # hide when no media is playing
      };
    }
    // lib.optionalAttrs hasButtons {
      "buttons-grid" = {
        buttons-per-row = 4;
        actions         = buttonActions;
      };
    }
    // lib.optionalAttrs cfg.hasBacklight {
      "backlight#display" = {
        label     = "󰃠";
        device    = cfg.backlightDevice;
        subsystem = "backlight";
        min       = 1;  # never go fully dark
      };
    }
    // lib.optionalAttrs cfg.hasKbBacklight {
      "backlight#kbd" = {
        label     = "󰌌";
        device    = cfg.kbBacklightDevice;
        subsystem = "leds";
        min       = 0;
      };
    };

  swayncConfig = {
    "$schema"                    = "/etc/xdg/swaync/configSchema.json";
    positionX                    = "right";
    positionY                    = "top";
    layer                        = "overlay";
    "control-center-layer"       = "top";
    "layer-shell"                = true;
    cssPriority                  = "user";
    "control-center-margin-top"    = 18;
    "control-center-margin-bottom" = 18;
    "control-center-margin-right"  = 18;
    "control-center-margin-left"   = 0;
    "notification-2fa-action"    = true;
    "notification-inline-replies"= false;
    "notification-icon-size"     = 40;    # deprecated but kept for compat
    "notification-body-image-height" = 80;
    "notification-body-image-width"  = 160;
    timeout          = 5;
    "timeout-low"    = 2;
    "timeout-critical" = 0;
    "fit-to-screen"  = true;
    "control-center-width"  = 420;
    "notification-window-width" = 480;
    "keyboard-shortcuts" = true;
    "image-visibility"   = "when-available";
    "transition-time"    = 100;
    "hide-on-clear"  = true;
    "hide-on-action" = true;
    "notification-grouping"  = false;
    "script-fail-notify"     = true;
    inherit widgets;
    "widget-config" = widgetConfig;
  };

in {
  home.file.".config/swaync/config.json" = {
    text = builtins.toJSON swayncConfig;
  };
}
