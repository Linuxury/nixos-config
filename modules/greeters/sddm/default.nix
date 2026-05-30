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
  # XCURSOR_THEME/SIZE        — In Wayland, the cursor image is provided by the
  #                              client (greeter), not the compositor. Without a
  #                              theme, Qt sends no cursor image → invisible cursor
  #                              even though mouse events are flowing normally.
  # XCURSOR_PATH              — xcursor defaults to /usr/share/icons which doesn't
  #                              exist on NixOS. Adwaita lives in the Nix system path.
  #                              Must be explicit or the theme lookup silently fails.
  #
  # KDE overrides this via a plain assignment in desktops/kde/default.nix
  # (priority 100 wins over mkDefault priority 1000) with its own
  # compositor-specific vars.
  services.displayManager.sddm.settings.General.GreeterEnvironment =
    lib.mkDefault "QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME= XCURSOR_THEME=Adwaita XCURSOR_SIZE=24 XCURSOR_PATH=/run/current-system/sw/share/icons";

  # Adwaita cursor theme — required by the greeter environment above.
  # Available system-wide so sddm user can resolve XCURSOR_THEME=Adwaita
  # via /run/current-system/sw/share/icons/Adwaita/cursors/.
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
