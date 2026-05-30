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

  # NixOS only sets [Theme] CursorTheme when cfg.theme == "" (default SDDM theme).
  # With a custom theme (catppuccin-sddm), it's omitted — and SDDM shows no cursor.
  # Set it explicitly here so the greeter always has a cursor regardless of theme.
  # Compositor modules override these to their preferred theme (e.g. BreezeX-Light).
  services.displayManager.sddm.settings.Theme = {
    CursorTheme = lib.mkDefault "Adwaita";
    CursorSize  = lib.mkDefault "24";
  };

  # SDDM authenticates via its own PAM service — "greetd" is not involved.
  # This unlocks the GNOME Keyring at login so apps (Proton Pass, SSH agent,
  # etc.) can access it without prompting for a password after the desktop loads.
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;  # TTY login fallback

  # sddm-greeter-qt6 must run as a pure Wayland client inside weston.
  #
  # GreeterEnvironment is comma-separated and only reaches the Qt greeter process
  # (NOT weston — weston inherits SDDM's process env, see systemd.services.sddm below).
  #
  # QT_QPA_PLATFORM=wayland   — forces Qt6 to use the Wayland QPA plugin.
  # QT_QPA_PLATFORMTHEME=     — CRITICAL: disables the gtk3 platform theme plugin.
  #                              Without this, Qt loads gtk3 → gtk_init() → tries X11
  #                              → no display → exit(1) → greeter crashes → black screen.
  # XCURSOR_THEME             — Qt6 Wayland cursor plugin reads this to select the theme.
  # XCURSOR_SIZE              — Cursor size in pixels.
  # XDG_DATA_DIRS             — Qt6's cursor plugin searches $XDG_DATA_DIRS/icons/ for
  #                              themes. NOT XCURSOR_PATH (that's an X11/libXcursor var).
  #                              Must point to the Nix system path or cursor stays invisible.
  #
  # Compositor modules override this via a plain assignment (priority 100 > mkDefault 1000).
  # KDE overrides it in desktops/kde/default.nix.
  services.displayManager.sddm.settings.General.GreeterEnvironment =
    lib.mkDefault "QT_QPA_PLATFORM=wayland,QT_QPA_PLATFORMTHEME=,XCURSOR_THEME=Adwaita,XCURSOR_SIZE=24,XCURSOR_PATH=/run/current-system/sw/share/icons,XDG_DATA_DIRS=/run/current-system/sw/share";

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
