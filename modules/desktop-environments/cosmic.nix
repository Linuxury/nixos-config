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

  # =========================================================================
  # Flatpak — Optional app distribution format
  #
  # COSMIC Store uses Flatpak as its backend.
  # Useful for apps not in nixpkgs or that need sandboxing.
  # =========================================================================
  services.flatpak.enable = true;

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
