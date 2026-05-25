# ===========================================================================
# modules/greeters/sddm-catppuccin.nix — SDDM + Catppuccin Mocha/Mauve theme
#
# Provides a polished GUI login screen that works on any GPU without cage.
#
# Wayland mode, default compositor: weston (lightweight, no KDE required).
# KDE hosts override the compositor in kde.nix via mkForce → kwin_wayland.
#
# Import this module in any DE module that needs a login screen:
#   imports = [ ../greeters/sddm-catppuccin.nix ];
#
# What this module owns:
#   - SDDM enable + Wayland mode (weston compositor by default)
#   - Catppuccin Mocha/Mauve theme
#   - GNOME Keyring unlock via SDDM PAM service
#   - sddm user video/input groups (needed for greeter GPU access)
#   - /run/user/175 tmpfiles entry (SDDM runtime dir for the greeter session)
#
# What each DE module still owns:
#   - Registering its own session package (services.displayManager.sessionPackages)
#   - Any compositor-specific SDDM overrides (KDE: CompositorCommand, GreeterEnvironment)
#   - services.gnome.gnome-keyring.enable (session-level concern, not greeter)
# ===========================================================================

{ pkgs, lib, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    # Wayland mode — uses weston by default (safe on any GPU, no kwin needed).
    # KDE overrides the compositor command in kde.nix via mkForce.
    wayland.enable = true;
    # Full store path avoids having to add catppuccin-sddm to systemPackages.
    theme = "${pkgs.catppuccin-sddm}/share/sddm/themes/catppuccin-mocha-mauve";
  };

  # SDDM authenticates via its own PAM service — "greetd" is not involved.
  # This unlocks the GNOME Keyring at login so apps (Proton Pass, SSH agent,
  # etc.) can access it without prompting for a password after the desktop loads.
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;  # TTY login fallback

  # sddm-greeter-qt6 runs inside weston's Wayland session. Without this, Qt6
  # defaults to the xcb (X11) QPA plugin, fails to open a display (no Xorg on
  # this system), and crashes immediately → black screen.
  # KDE hosts override this in kde.nix (they set their own GreeterEnvironment
  # with KWIN_DRM_DEVICES and QT_QPA_PLATFORMTHEME= alongside QT_QPA_PLATFORM).
  services.displayManager.sddm.settings.General.GreeterEnvironment =
    lib.mkDefault "QT_QPA_PLATFORM=wayland";

  # SDDM runs the greeter compositor (weston or kwin) as the sddm system user.
  # video: GPU access for rendering the login screen.
  # input: keyboard/mouse input before any user session starts.
  users.users.sddm.extraGroups = [ "video" "input" ];

  # SDDM sets XDG_RUNTIME_DIR=/run/user/175 for the sddm user (uid 175 on NixOS)
  # but systemd-logind never creates it for greeter sessions — create it manually.
  systemd.tmpfiles.rules = [
    "d /run/user/175 0700 sddm sddm -"
  ];
}
