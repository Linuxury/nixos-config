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
  imports = [
    # Firefox with enforced policies — applies to every user on every
    # graphical host. Policies are declared once here rather than in
    # each host config. See modules/base/firefox.nix for full details.
    ./firefox.nix
  ];

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
  # KDE Connect — Phone/desktop integration
  #
  # Lets your phone and desktop share clipboard, notifications, files,
  # and more. Works on any DE — the name is misleading, it's DE-agnostic.
  # The NixOS module opens the required firewall ports (1714-1764) automatically.
  # =========================================================================
  programs.kdeconnect.enable = true;

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
    showtime    # GNOME video player — clean GTK4 GUI for casual viewing
    amberol     # Music player — simple, modern, no library management needed
    loupe       # GNOME image viewer — thumbnails, zoom, EXIF

    # -----------------------------------------------------------------------
    # Documents & disks
    # -----------------------------------------------------------------------
    papers             # GNOME document viewer — PDFs and more (GTK4, modern)
    gnome-disk-utility # Disk management GUI — partition, format, check health

    # -----------------------------------------------------------------------
    # System monitoring
    # -----------------------------------------------------------------------
    mission-center  # Modern system monitor — CPU, RAM, GPU, network at a glance

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
