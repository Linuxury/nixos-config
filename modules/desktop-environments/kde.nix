# ===========================================================================
# modules/desktop-environments/kde.nix — KDE Plasma Desktop Environment
#
# KDE Plasma is a full-featured, highly customizable desktop environment.
# Your wife is already comfortable with it, so it's available as a fallback
# option on her machines if she ever wants to switch from COSMIC.
#
# To enable it on a host, simply import this module alongside cosmic.nix.
# Both can coexist — the user picks which one to log into at the login screen.
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  # =========================================================================
  # KDE Plasma 6
  #
  # plasma6 is the current generation of KDE.
  # enabling it automatically pulls in Qt6, KDE frameworks, and Plasma itself.
  # =========================================================================
  services.desktopManager.plasma6.enable = true;

  # =========================================================================
  # Qt platform theme
  #
  # NixOS defaults QT_QPA_PLATFORMTHEME=gtk2 for GTK integration. With KDE,
  # this causes kwin_wayland to crash on startup — GTK2's platform theme calls
  # gtk_init() which requires an X11 display, but kwin IS the display and
  # hasn't started one yet. Set it to "kde" so Qt uses KDE's native theme.
  # =========================================================================
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkForce "kde";

  # =========================================================================
  # Display Manager (Login Screen)
  #
  # KDE Plasma 6.6 introduced "Plasma Login Manager", a new native KDE
  # display manager forked from SDDM with better multi-monitor, HDR, and
  # high-DPI support. It is still marked as optional/in-development.
  #
  # We use SDDM for now as it is stable and well-supported in nixpkgs.
  # When Plasma Login Manager matures and lands in nixpkgs, switching will
  # be a one-line change here.
  # =========================================================================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # Clear QT_QPA_PLATFORMTHEME for the greeter process — it inherits the
    # system value (gtk2) which crashes sddm-greeter-qt6 the same way.
    settings.General.GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QT_QPA_PLATFORMTHEME=";
  };

  # SDDM strips its own environment before launching kwin_wayland, so env vars
  # set on display-manager.service never reach kwin. The only reliable way to
  # inject env vars into kwin is via the CompositorCommand in the SDDM config.
  #
  # - KWIN_DRM_DEVICES: On Ryzen 7840U the NPU (amdxdna) claims DRM minor 0,
  #   pushing amdgpu to card1. kwin defaults to card0, finds nothing, exits 1.
  # - QT_QPA_PLATFORMTHEME=: Clear it for the greeter kwin too (same crash).
  services.displayManager.sddm.settings.Wayland.CompositorCommand = lib.mkForce
    "env KWIN_DRM_DEVICES=/dev/dri/card1 QT_QPA_PLATFORMTHEME= ${pkgs.kdePackages.kwin}/bin/kwin_wayland --no-global-shortcuts --no-kactivities --no-lockscreen --locale1";

  # sddm runs kwin_wayland as the greeter compositor. kwin needs access to
  # /dev/dri/card* (video group) and /dev/input/* (input group).
  users.users.sddm.extraGroups = [ "video" "input" ];

  # SDDM sets XDG_RUNTIME_DIR=/run/user/175 but logind never creates it for
  # greeter sessions. Create it so kwin and dbus can use it.
  systemd.tmpfiles.rules = [
    "d /run/user/175 0700 sddm sddm -"
  ];

  # =========================================================================
  # XDG Portal for KDE
  #
  # Same portal system as COSMIC but using KDE's implementation.
  # Handles file pickers, screen sharing etc for KDE apps.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  # =========================================================================
  # KDE core packages
  #
  # Plasma comes with a lot built in, but these are commonly needed extras.
  # Keep this minimal — user preference apps belong in home.nix.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    kdePackages.kate          # KDE text editor
    kdePackages.dolphin       # KDE file manager
    kdePackages.ark           # Archive manager (zip, tar, etc)
    kdePackages.kcalc         # Calculator
    kdePackages.okular        # Document viewer (PDF, etc)
    kdePackages.gwenview      # Image viewer
    kdePackages.plasma-browser-integration  # Browser integration for KDE
  ];

  # =========================================================================
  # TODO: plasma-foreground-booster (kdePackages.kcgroups)
  #
  # Once kcgroups lands in nixpkgs, add it here. It's the KDE-specific piece
  # that signals the focused window to dmemcg-booster (already enabled via
  # gaming.nix). Without it the daemon runs but has no focus awareness.
  # =========================================================================

}
