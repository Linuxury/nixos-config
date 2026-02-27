# ===========================================================================
# modules/base/graphical-base.nix — Shared base for all graphical machines
#
# Import this in every host that runs a desktop environment — desktops and
# laptops. Do NOT import on headless servers.
#
# Deliberately DE-agnostic: this module works identically whether the host
# runs COSMIC, KDE, Hyprland, Niri, or any other DE. When you add a new
# DE module to a host, graphical-base.nix stays in the imports unchanged.
#
# Servers stay clean — they never import this file, so they never get
# Wayland tools, terminal emulators, or media players they can't use.
#
# Import placement: hosts/<name>/default.nix
#   imports = [
#     common.nix
#     graphical-base.nix   ← here, before the DE module
#     cosmic.nix           ← or kde.nix, hyprland.nix, etc.
#     ...
#   ]
# ===========================================================================

{ config, pkgs, ... }:

{
  # =========================================================================
  # GVfs — GNOME Virtual Filesystem
  #
  # Provides virtual filesystem support so graphical file managers can
  # browse network shares (SMB/Samba), remote filesystems, and more.
  #
  # Works with any file manager that uses GIO/GVfs as a backend:
  #   COSMIC Files, Dolphin (KDE), Nautilus (GNOME), Thunar (XFCE), etc.
  #
  # The gvfs package in nixpkgs is compiled with samba support.
  # The samba package below provides libsmbclient which gvfs needs at runtime.
  # =========================================================================
  services.gvfs.enable = true;

  # =========================================================================
  # Shared graphical packages
  #
  # Installed on every machine that runs a desktop environment.
  # Servers never get these — they have no graphical session to use them.
  # =========================================================================
  environment.systemPackages = with pkgs; [

    # -----------------------------------------------------------------------
    # Terminals
    # -----------------------------------------------------------------------
    ghostty     # Fast GPU-accelerated terminal — primary terminal for the family
    kitty       # Alternative GPU-accelerated terminal

    # -----------------------------------------------------------------------
    # Media
    # -----------------------------------------------------------------------
    mpv         # Lightweight video player — plays almost any format
    imv         # Minimal Wayland image viewer

    # -----------------------------------------------------------------------
    # Wayland / desktop integration
    # -----------------------------------------------------------------------
    wl-clipboard  # wl-copy / wl-paste — Wayland clipboard access from scripts
    xdg-utils     # xdg-open — opens files with the correct default app

    # -----------------------------------------------------------------------
    # Network share client
    #
    # Provides libsmbclient — the library gvfs (above) links against at
    # runtime to browse SMB/Samba shares. Without this, clicking
    # "Network" in any file manager will fail to connect to your servers.
    # -----------------------------------------------------------------------
    samba
  ];
}
