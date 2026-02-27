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
  # XDG Portal — Desktop integration layer
  #
  # Portals allow sandboxed apps (like Flatpaks) to interact with the
  # desktop — file pickers, screen sharing, notifications, etc.
  # COSMIC provides its own portal implementation.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-cosmic ];
    config.common.default = "cosmic";
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
  # GVfs — GNOME Virtual Filesystem
  #
  # Enables the gvfs daemon so COSMIC Files (and other file managers) can
  # browse network shares — including Samba (SMB) shares on your local
  # network. Without this, network locations won't appear in the file manager
  # sidebar and smb:// URIs won't open.
  #
  # The gvfs package in nixpkgs is compiled with samba support, so no extra
  # packages are needed — just enable the service and include samba for the
  # underlying libsmbclient that gvfs uses.
  # =========================================================================
  services.gvfs.enable = true;

  environment.systemPackages = with pkgs; [
    samba  # Provides libsmbclient — required by gvfs for SMB share browsing
  ];

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
