# ===========================================================================
# modules/controllers/default.nix — Controller support
#
# System-wide plug-and-play support for all controllers in the house:
#   - 8BitDo Ultimate (2dc8:*)     — covered by game-devices-udev-rules
#   - Steam Controller (28de:1304) — sc-controller daemon + Valve udev rules
#   - Anbernic RG P01  (3537:1007) — custom udev rule (not in upstream yet)
#
# sc-controller daemon autostarts on graphical login so the Steam Controller
# works at the desktop without Steam running. Open `sc-controller` GUI to
# configure profiles, touchpad behaviour, gyro, and button mappings.
#
# Import this module on any host where controllers will be used.
# It pairs with modules/gaming/default.nix but is independent — controllers
# work in non-gaming contexts too (desktop navigation, media control).
# ===========================================================================

{ pkgs, lib, ... }:

let
  # =========================================================================
  # sc-controller — patched to support the Steam Controller Puck (28de:1304)
  #
  # nixpkgs ships sc-controller 0.5.5 which only registers hotplug callbacks
  # for the wired controller (0x1102), the original wireless dongle (0x1142),
  # and the Steam Deck (0x1205). The newer "Puck" wireless receiver (0x1304)
  # uses the identical Valve HID protocol — only the USB product ID differs.
  #
  # One extra register_hotplug_device call in sc_dongle.py is all that's
  # needed. The full Dongle class (touchpads, gyro, haptics, serial) works
  # unchanged.
  #
  # Track upstream: https://github.com/C0rn3j/sc-controller
  # Remove this override once sc-controller natively registers 0x1304.
  # =========================================================================
  sc-controller = pkgs.sc-controller.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i \
        's|register_hotplug_device(cb, VENDOR_ID, PRODUCT_ID)$|register_hotplug_device(cb, VENDOR_ID, PRODUCT_ID)\n\tregister_hotplug_device(cb, VENDOR_ID, 0x1304)  # Steam Controller Puck|' \
        scc/drivers/sc_dongle.py
    '';
  });
in
{
  # =========================================================================
  # Kernel modules
  #
  # uinput    — virtual input device creation; required by sc-controller to
  #             emulate a gamepad/keyboard/mouse from the Steam Controller's
  #             raw HID stream.
  # hid_steam — in-kernel HID driver for Valve controllers; gives the OS
  #             basic visibility into the device before sc-controller takes
  #             over with a full profile.
  # =========================================================================
  boot.kernelModules = [ "uinput" "hid_steam" ];

  # =========================================================================
  # udev rules — device access for non-root users
  #
  # game-devices-udev-rules covers:
  #   - All 8BitDo devices (vendor 2dc8) — blanket + per-product rules
  #   - All Valve devices (vendor 28de)  — blanket rule covering Steam Controller
  #   - PlayStation, Xbox, Nintendo, Logitech, Razer, and many more
  #
  # The Anbernic RG P01 (3537:1007) is not in the upstream package yet so
  # a manual rule is added below. Without it the device is only accessible
  # as root and antimicrox / SDL games won't see it on Wayland.
  #
  # Track upstream: https://codeberg.org/fabiscafe/game-devices-udev
  # Remove the extraRules block once Anbernic 3537:1007 is merged upstream.
  # =========================================================================
  services.udev.packages = with pkgs; [
    game-devices-udev-rules
  ];

  services.udev.extraRules = ''
    # Anbernic RG P01 (3537:1007) — not in game-devices-udev-rules yet
    ACTION!="remove", SUBSYSTEM=="usb",    ATTRS{idVendor}=="3537", ATTRS{idProduct}=="1007", MODE="0660", TAG+="uaccess"
    ACTION!="remove", KERNEL=="hidraw*",   ATTRS{idVendor}=="3537", ATTRS{idProduct}=="1007", MODE="0660", TAG+="uaccess"
    ACTION!="remove", KERNEL=="js*",       ATTRS{idVendor}=="3537", ATTRS{idProduct}=="1007", MODE="0660", TAG+="uaccess"
    ACTION!="remove", KERNEL=="event*",    ATTRS{idVendor}=="3537", ATTRS{idProduct}=="1007", MODE="0660", TAG+="uaccess"
  '';

  # =========================================================================
  # Packages
  #
  # sc-controller — standalone Steam Controller driver and profile manager.
  #   The GUI (sc-controller) lets you build profiles: map touchpads to mouse
  #   or d-pad, configure gyro, set per-application profiles, create macros.
  #   The daemon (scc-daemon) runs in the background and applies the active
  #   profile without Steam. Patched above to add Puck support (28de:1304).
  #
  # antimicrox — maps any controller's buttons/sticks to keyboard keys or
  #   mouse actions. Useful for apps with no native controller support.
  # =========================================================================
  environment.systemPackages = [
    sc-controller
    pkgs.antimicrox
  ];

  # =========================================================================
  # sc-controller daemon — autostart on graphical login
  #
  # Starts scc-daemon as a user systemd service tied to the graphical session.
  # This means the Steam Controller is active the moment you log in —
  # no need to open Steam or launch sc-controller manually.
  #
  # To configure profiles: run `sc-controller` from the app launcher.
  # Profiles are saved to ~/.config/scc/profiles/ and persist across reboots.
  # The built-in "Desktop" profile (loaded by default) mirrors the Steam Deck
  # desktop layout: right pad = trackball mouse, left pad = scroll, RT = left
  # click, LT = right click, stick = arrow keys.
  #
  # The daemon exits cleanly when the graphical session ends (partOf ensures
  # systemd stops it on logout rather than leaving it orphaned).
  # =========================================================================
  systemd.user.services.scc-daemon = {
    description = "SC Controller — standalone Steam Controller daemon";
    wantedBy    = [ "graphical-session.target" ];
    after       = [ "graphical-session.target" ];
    partOf      = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${sc-controller}/bin/scc-daemon --foreground start";
      Restart    = "on-failure";
      RestartSec = 3;
    };
  };
}
