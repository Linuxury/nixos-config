# ===========================================================================
# modules/greeters/sddm/default.nix — SDDM + Catppuccin Mocha/Mauve theme
#
# Provides a polished GUI login screen that works on any GPU without cage.
#
# Wayland mode, default compositor: weston (lightweight, no KDE required).
# KDE hosts override the compositor in desktops/kde/default.nix via mkForce.
#
# Import this module in any DE module that needs a login screen:
#   imports = [ ../../greeters/sddm/default.nix ];
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
    # KDE overrides the compositor command in desktops/kde/default.nix via mkForce.
    wayland.enable = true;
    # Full store path avoids having to add catppuccin-sddm to systemPackages.
    theme = "${pkgs.catppuccin-sddm}/share/sddm/themes/catppuccin-mocha-mauve";
  };

  # SDDM authenticates via its own PAM service — "greetd" is not involved.
  # This unlocks the GNOME Keyring at login so apps (Proton Pass, SSH agent,
  # etc.) can access it without prompting for a password after the desktop loads.
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;  # TTY login fallback

  # sddm-greeter-qt6 must run as a pure Wayland client inside weston.
  #
  # QT_QPA_PLATFORM=wayland   — forces Qt6 to use the Wayland QPA plugin
  #                              instead of xcb (X11), which doesn't exist here.
  # QT_QPA_PLATFORMTHEME=     — CRITICAL: disables the gtk3 platform theme plugin.
  #                              Without this, Qt loads the gtk3 theme which calls
  #                              gtk_init(); GTK tries X11, finds no display, and
  #                              calls exit(1) → greeter crashes → black screen.
  #                              (KDE uses the same workaround in desktops/kde.)
  #
  # GreeterEnvironment is comma-separated and only reaches the Qt greeter process.
  # KDE overrides this via a plain assignment in desktops/kde/default.nix.
  services.displayManager.sddm.settings.General.GreeterEnvironment =
    lib.mkDefault "QT_QPA_PLATFORM=wayland,QT_QPA_PLATFORMTHEME=";

  # Weston (the greeter compositor) is launched by SDDM and inherits SDDM's own
  # process environment — NOT GreeterEnvironment. Weston reads XCURSOR_THEME and
  # XCURSOR_PATH from its environment to render the cursor for all Wayland clients.
  # Setting them here (on the sddm systemd unit) makes them available to Weston.
  #
  # Compositor modules (e.g. hyprland) override these to their preferred theme.
  # Adwaita is the safe fallback: always available via adwaita-icon-theme below.
  systemd.services.sddm.environment = {
    XCURSOR_THEME = lib.mkDefault "Adwaita";
    XCURSOR_SIZE  = lib.mkDefault "24";
    XCURSOR_PATH  = lib.mkDefault "/run/current-system/sw/share/icons";
  };

  # Adwaita cursor — fallback theme, always available system-wide.
  environment.systemPackages = [ pkgs.adwaita-icon-theme ];

  # seatd manages seat (GPU/input device) access for Wayland compositors.
  # With seatd running, libseat in weston and MangoWC/kwin uses seatd's backend
  # instead of logind's. seatd handles DRM master handoff between compositors
  # cleanly (greeter exits → user compositor takes over) without the VT race
  # condition that occurs with the logind backend.
  # The 'seat' group is required for any user/process that needs seat access.
  services.seatd.enable = true;
  users.users.sddm.extraGroups = [ "video" "input" "seat" ];

  # SDDM sets XDG_RUNTIME_DIR=/run/user/175 for the sddm user (uid 175 on NixOS)
  # but systemd-logind never creates it for greeter sessions — create it manually.
  systemd.tmpfiles.rules = [
    "d /run/user/175 0700 sddm sddm -"
  ];
}
