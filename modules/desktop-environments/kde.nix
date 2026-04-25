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

{ config, pkgs, ... }:

{
  # =========================================================================
  # KDE Plasma 6
  #
  # plasma6 is the current generation of KDE.
  # enabling it automatically pulls in Qt6, KDE frameworks, and Plasma itself.
  # =========================================================================
  services.desktopManager.plasma6.enable = true;

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
  };

  # kwin_wayland (used by SDDM Wayland greeter and Plasma sessions) picks DRM
  # devices in order. On this machine, simpledrm (EFI framebuffer) registers as
  # card0 before amdgpu gets card1. kwin_wayland tries card0 first, fails
  # because simpledrm doesn't support atomic modesetting, and exits with code 1
  # — leaving a black screen. Pointing it at card1 (the real amdgpu device) fixes this.
  systemd.services.display-manager.environment = {
    KWIN_DRM_DEVICES = "/dev/dri/card1";
    # Verbose kwin logging — remove once crash is diagnosed
    QT_LOGGING_RULES = "kwin.*=true";
  };

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
