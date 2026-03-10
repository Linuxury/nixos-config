# ===========================================================================
# modules/desktop-environments/cosmic.nix — COSMIC Desktop Environment
#
# COSMIC is System76's Rust-based desktop environment.
# Available natively in nixpkgs as of NixOS 25.05 — no external flake needed.
#
# This module is the DEFAULT desktop for all non-server hosts.
# It gets enabled in every desktop and laptop host config.
# ===========================================================================

{ config, pkgs, inputs, ... }:

{
  services.desktopManager.cosmic.enable = true;

  # =========================================================================
  # COSMIC Data Control — Wayland clipboard protocol
  #
  # Enables the zwlr_data_control_v1 Wayland protocol, which allows
  # clipboard manager applets (like the one in the COSMIC panel) to read
  # and monitor clipboard content from other applications.
  # Without this, the clipboard applet is visible but non-functional.
  # =========================================================================
  environment.variables.COSMIC_DATA_CONTROL_ENABLED = "1";

  # =========================================================================
  # COSMIC Display Manager
  #
  # The display manager is the login screen you see before the desktop loads.
  # cosmic-greeter is COSMIC's own login screen, designed to match the DE.
  # We disable any other display manager to avoid conflicts.
  # =========================================================================
  services.displayManager.cosmic-greeter.enable = true;

  # =========================================================================
  # XWayland — X11 compatibility layer
  #
  # Runs an X server inside the Wayland session so legacy X11 apps
  # (and Electron apps forced to XWayland mode) work without a native
  # Wayland renderer. COSMIC's module may enable this implicitly, but
  # declaring it here makes the dependency explicit and clear.
  # =========================================================================
  programs.xwayland.enable = true;

  # =========================================================================
  # XDG Portal — Desktop integration layer
  #
  # Portals allow sandboxed apps (like Flatpaks) to interact with the
  # desktop — file pickers, screen sharing, notifications, etc.
  # COSMIC provides its own portal implementation.
  # =========================================================================
  xdg.portal = {
    enable = true;
    # xdg-desktop-portal-gtk acts as a fallback for portal interfaces that
    # COSMIC hasn't implemented yet (e.g. some Flatpak app requests).
    # "cosmic;gtk" means: try COSMIC first, fall back to GTK if unavailable.
    extraPortals = [ pkgs.xdg-desktop-portal-cosmic pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "cosmic;gtk";
  };

  # =========================================================================
  # Pipewire screen sharing support
  # Required for screen sharing to work in browsers and apps under COSMIC.
  # =========================================================================
  services.pipewire.enable = true; # Already set in common.nix but safe to repeat

  # =========================================================================
  # COSMIC-specific packages
  #
  # These are apps that ship as part of the COSMIC ecosystem.
  # Only install what makes sense system-wide here.
  # User-specific apps belong in the user's home.nix instead.
  # =========================================================================
  # COSMIC apps (files, text-editor, store, terminal, etc.) are bundled
  # automatically by services.desktopManager.cosmic.enable — no need to
  # list them here. Adding them explicitly causes "undefined variable" errors
  # when package names change in the nixos-cosmic flake.
  #
  # Community COSMIC extensions available in nixpkgs go here.
  # Still on Flatpak (not yet in nixpkgs — migrate when they land):
  #   Clipboard Manager  → io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager
  #   Tempest weather    → com.vintagetechie.CosmicExtAppletTempest
  environment.systemPackages = with pkgs; [
    cosmic-ext-applet-privacy-indicator  # Camera/mic/screen-share indicator in panel
  ];

  # =========================================================================
  # Flatpak — Optional app distribution format
  #
  # COSMIC Store uses Flatpak as its backend.
  # Useful for apps not in nixpkgs or that need sandboxing.
  #
  # The activation script adds Flathub at system scope on first boot.
  # This is required for COSMIC Store to browse and display apps —
  # user-level remotes are not visible to the system Flatpak installation
  # that COSMIC Store queries.
  # =========================================================================
  services.flatpak.enable = true;

  # =========================================================================
  # PackageKit — D-Bus package management abstraction
  #
  # COSMIC Store queries PackageKit for the "Installed" and "Updates" views.
  # Without this service running, Store logs ServiceUnknown D-Bus errors and
  # cannot list system packages. PackageKit has no Nix backend so it won't
  # manage Nix packages, but the daemon must be present for Store to function.
  # =========================================================================
  services.packagekit.enable = true;

  system.activationScripts.flatpak-flathub = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
    '';
    deps = [ "specialfs" ];
  };

  # =========================================================================
  # Wallpaper slideshow + matugen theming — injected into every HM user
  #
  # home-manager.sharedModules adds this HM module to all users on any host
  # that imports cosmic.nix. No need to import it individually in each
  # user's home.nix — it's automatic for every COSMIC desktop.
  # =========================================================================
  home-manager.sharedModules = [
    ../services/wallpaper-slideshow.nix
  ];

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # Without a keyring, apps like Zed and browsers that use the Secret Service
  # API (via libsecret) will prompt for a password on every launch instead of
  # reading stored credentials. GNOME Keyring works fine outside of GNOME —
  # it's just a DBus daemon implementing the Secret Service spec.
  #
  # enableGnomeKeyring on the login PAM service makes cosmic-greeter unlock
  # the keyring automatically at login so no separate unlock prompt appears.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # =========================================================================
  # Fonts — Basic font set for a readable desktop experience
  #
  # These are system-wide fonts available to all users.
  # Users can add more fonts in their own home.nix.
  # =========================================================================
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts          # Wide unicode coverage, clean and readable
      noto-fonts-cjk-sans # Chinese, Japanese, Korean support
      noto-fonts-color-emoji    # Emoji support
      liberation_ttf      # Free replacements for Arial, Times New Roman etc
      # JetBrainsMono Nerd Font (all three variants: Mono, Regular, Propo)
      # nerd-fonts.jetbrains-mono is also declared in common.nix —
      # NixOS deduplicates font packages so listing it here is harmless.
      nerd-fonts.jetbrains-mono
    ];
    fontconfig = {
      defaultFonts = {
        serif     = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };
}
