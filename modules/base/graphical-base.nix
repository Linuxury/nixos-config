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

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Firefox with enforced policies — applies to every user on every
    # graphical host. Policies are declared once here rather than in
    # each host config. See modules/base/firefox.nix for full details.
    ./firefox.nix

    # Fast-fail pre-check for the Torrents CIFS automount.
    # Self-activating: only applies to hosts that have /mnt/Torrents
    # in fileSystems. No-op on hosts without it.
    ./torrents-precheck.nix

    # AccountsService avatars — copies per-user icons from
    # /home/linuxury/Pictures/Avatar/ so they appear in the greeter.
    ./user-avatars.nix

    # LibreOffice via Flathub — installed on first login for every graphical
    # user. Skips gracefully on hosts where Flathub has been removed.
    ./libreoffice.nix

    # Fluxer via Flathub — self-hostable community platform replacing Discord.
    # Installed on first login for every graphical user.
    ./fluxer.nix
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
  # Flatpak — App distribution for packages not in nixpkgs
  #
  # Required by user-level services like hytale-flatpak-install.
  # Available on all graphical hosts regardless of DE.
  # The activation script adds Flathub at system scope on first boot.
  # =========================================================================
  services.flatpak.enable = true;
  system.activationScripts.flatpak-flathub = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
    '';
    deps = [ "specialfs" ];
  };

  # Qt theming — makes Qt apps follow the active GTK theme automatically.
  # qt6gtk2 reads GTK3 settings at runtime, so Qt apps blend with the desktop
  # without requiring a separate Qt configurator tool.
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "gtk2";

  # Ensure flatpak desktop files/icons are discoverable by launchers
  environment.sessionVariables.XDG_DATA_DIRS = [
    "/var/lib/flatpak/exports/share"
    "$HOME/.local/share/flatpak/exports/share"
    "$XDG_DATA_DIRS"
  ];

  # =========================================================================
  # Bluetooth
  #
  # Enables the bluez stack (kernel + userspace) and the blueman GUI manager.
  # blueman is DE-agnostic — it works on COSMIC, Hyprland, KDE, and anything
  # else. powerOnBoot = false leaves the adapter off until the user turns it
  # on, avoiding unnecessary radio activity on hosts that rarely use it.
  # =========================================================================
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault false;
  services.blueman.enable = true;

  # Load btusb at boot so /sys/class/bluetooth exists before bluetoothd
  # evaluates its ConditionPathIsDirectory check. Without this, the service
  # silently skips itself on machines where the module isn't loaded early.
  boot.kernelModules = [ "btusb" ];

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
    kitty       # Primary GPU-accelerated terminal

    # -----------------------------------------------------------------------
    # Media
    # -----------------------------------------------------------------------
    showtime    # GNOME video player — clean GTK4 GUI for casual viewing
    gapless     # Music player — GTK4, gapless playback, fast and lightweight
    loupe       # GNOME image viewer — thumbnails, zoom, EXIF

    # -----------------------------------------------------------------------
    # Documents & office
    # -----------------------------------------------------------------------
    papers                   # GNOME document viewer — PDFs and more (GTK4, modern)

    # -----------------------------------------------------------------------
    # System monitoring
    # -----------------------------------------------------------------------
    mission-center  # Modern system monitor — CPU, RAM, GPU, network at a glance

    # -----------------------------------------------------------------------
    # Wayland / desktop integration
    # -----------------------------------------------------------------------
    wl-clipboard           # wl-copy / wl-paste — Wayland clipboard access from scripts
    xdg-utils              # xdg-open — opens files with the correct default app
    qt6Packages.qt6gtk2    # Qt6 GTK platform theme — makes Qt apps follow the active GTK theme

    # GSettings schemas for GNOME/GTK desktop preferences.
    # COSMIC does not ship these, but GTK apps like Firefox read
    # org.gnome.desktop.wm.preferences:button-layout from this package
    # to know which window buttons (minimize, maximize, close) to draw.
    # Without it, Firefox CSD defaults to close-only on COSMIC.
    gsettings-desktop-schemas

    # -----------------------------------------------------------------------
    # Shell tools
    # -----------------------------------------------------------------------
    eza   # Modern ls replacement — colors, icons, git status, dir grouping

    # -----------------------------------------------------------------------
    # Browsers
    # -----------------------------------------------------------------------
    inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.helium  # Privacy-focused Chromium browser

    # -----------------------------------------------------------------------
    # Network share client
    #
    # Provides libsmbclient — the library gvfs (above) links against at
    # runtime to browse SMB/Samba shares. Without this, clicking
    # "Network" in any file manager will fail to connect to your servers.
    # -----------------------------------------------------------------------
    samba

  ];

  # =========================================================================
  # Fonts — Basic font set for a readable desktop experience
  #
  # These are system-wide fonts available to all graphical hosts,
  # regardless of which DE/WM is running. Declared here so every host
  # (COSMIC, Hyprland, KDE, Niri, etc.) gets the same font stack.
  # Users can add more fonts in their own home.nix.
  # =========================================================================
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts               # Wide unicode coverage, clean and readable
      noto-fonts-cjk-sans      # Chinese, Japanese, Korean support
      liberation_ttf           # Free replacements for Arial, Times New Roman etc
      # noto-fonts-color-emoji intentionally omitted — it steals the
      # private-use-area codepoints that Nerd Fonts uses for icons,
      # breaking fastfetch and terminal icon rendering.
      # Nerd Fonts (all families) are already installed via common.nix.
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
