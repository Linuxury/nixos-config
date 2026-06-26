# ===========================================================================
# modules/system/graphical/default.nix — Shared base for all graphical machines
#
# Import this in every host that runs a desktop environment — desktops and
# laptops. Do NOT import on headless servers.
#
# Deliberately DE-agnostic: this module works identically whether the host
# runs COSMIC, KDE, Hyprland, Niri, or any other DE. When you add a new
# DE module to a host, graphical/default.nix stays in the imports unchanged.
#
# Servers stay clean — they never import this file, so they never get
# Wayland tools, terminal emulators, or media players they can't use.
#
# The following are intentionally NOT imported here — they are per-host:
#   firefox, helium, libreoffice, fluxer, openrgb, kdeconnect,
#   lemokey-keychron, zen-browser, zed, lm-studio.
#
# Import placement: hosts/<name>/default.nix
#   imports = [
#     system/core/default.nix
#     system/graphical/default.nix   ← here, before the DE module
#     compositors/hyprland/default.nix  ← or desktops/{cosmic,kde,...}
#     ...
#   ]
# ===========================================================================

{ config, lib, pkgs, ... }:

{
  imports = [
    # Fast-fail pre-check for the Torrents CIFS automount.
    # Self-activating: only applies to hosts that have /mnt/Torrents
    # in fileSystems. No-op on hosts without it.
    ./torrents-precheck/default.nix

    # AccountsService avatars — copies per-user icons from
    # /home/linuxury/Pictures/Avatar/ so they appear in the greeter.
    ./user-avatars/default.nix
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

  # =========================================================================
  # NumLock — enable before the greeter on every graphical host
  #
  # Writes the LED state directly to the kernel before display-manager starts.
  # This is the universal approach: SDDM, cosmic-greeter, and all Wayland
  # compositors read the initial numlock state from the kernel at startup.
  # SDDM hosts also get Numlock = "on" in greeters/sddm as belt-and-suspenders.
  # =========================================================================
  systemd.services.numlock-on = {
    description = "Enable NumLock";
    wantedBy = [ "display-manager.service" ];
    before   = [ "display-manager.service" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart       = pkgs.writeShellScript "numlock-on" ''
        for kbd in /sys/class/leds/*::numlock; do
          echo 1 > "$kbd/brightness" 2>/dev/null || true
        done
      '';
    };
  };

  # =========================================================================
  # Bluetooth — graphical host tuning (base service enabled in core)
  #
  # core enables bluetoothd + blueman and suppresses the blueman-applet
  # autostart system-wide. Here we apply settings appropriate for any
  # machine with a display:
  #
  #   powerOnBoot     — adapter comes up immediately; every graphical host
  #                     has at least one paired device (headset, mouse, kb).
  #   FastConnectable — allows more radio bandwidth during connection setup,
  #                     speeding up reconnection at the cost of slightly higher
  #                     power during that window. Fine for desktops/laptops.
  #   AutoEnable      — re-enables the adapter if bluetoothd restarts (e.g.
  #                     after a suspend/resume cycle that resets the adapter).
  #
  # DE-specific BT management (COSMIC panel, KDE system tray, Noctalia bar)
  # is handled by each DE — no compositor module needs to set these.
  # =========================================================================
  hardware.bluetooth = {
    powerOnBoot = true;
    settings = {
      General.FastConnectable = true;
      Policy.AutoEnable      = true;
    };
  };

  # =========================================================================
  # Backlight — brightness control
  #
  # Adds a udev rule that makes /sys/class/backlight/*/brightness writable
  # by the "video" group. No-op on desktops (rule fires only when a backlight
  # device appears). DE-agnostic: works with COSMIC, Hyprland, KDE, etc.
  # =========================================================================
  hardware.acpilight.enable = true;

  # Required for dconf/GSettings to work on non-GNOME desktops.
  # Installs the D-Bus service activation entry so that `dconf load`
  # (used by Home Manager) and GTK apps using GSettings can start
  # dconf-service on demand.
  programs.dconf.enable = true;

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
    neovim                   # Fallback text editor — always available on every graphical host

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
  # =========================================================================
  # Default applications — shared across all graphical users on this host
  #
  # Using home-manager.sharedModules so these defaults travel with the
  # packages that provide them. When an optional app module is not imported,
  # its MIME entries simply don't exist — no dangling declarations.
  #
  # Per-user choices (browser) stay in each user's home.nix.
  # Optional app defaults (LibreOffice, etc.) live in their own modules.
  # =========================================================================
  home-manager.sharedModules = [
    ./keybinds/default.nix
    {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # -----------------------------------------------------------------------
        # File Manager — Nautilus
        # -----------------------------------------------------------------------
        "inode/directory" = "org.gnome.Nautilus.desktop";

        # -----------------------------------------------------------------------
        # Image Viewer — Loupe
        # -----------------------------------------------------------------------
        "image/jpeg"              = "org.gnome.Loupe.desktop";
        "image/png"               = "org.gnome.Loupe.desktop";
        "image/gif"               = "org.gnome.Loupe.desktop";
        "image/webp"              = "org.gnome.Loupe.desktop";
        "image/avif"              = "org.gnome.Loupe.desktop";
        "image/heic"              = "org.gnome.Loupe.desktop";
        "image/jxl"               = "org.gnome.Loupe.desktop";
        "image/bmp"               = "org.gnome.Loupe.desktop";
        "image/tiff"              = "org.gnome.Loupe.desktop";
        "image/svg+xml"           = "org.gnome.Loupe.desktop";
        "image/x-portable-pixmap" = "org.gnome.Loupe.desktop";

        # -----------------------------------------------------------------------
        # Video Player — Showtime
        # -----------------------------------------------------------------------
        "video/mp4"        = "org.gnome.Showtime.desktop";
        "video/x-matroska" = "org.gnome.Showtime.desktop";
        "video/x-msvideo"  = "org.gnome.Showtime.desktop";
        "video/webm"       = "org.gnome.Showtime.desktop";
        "video/quicktime"  = "org.gnome.Showtime.desktop";
        "video/mpeg"       = "org.gnome.Showtime.desktop";
        "video/x-flv"      = "org.gnome.Showtime.desktop";
        "video/ogg"        = "org.gnome.Showtime.desktop";
        "video/x-ms-wmv"   = "org.gnome.Showtime.desktop";

        # -----------------------------------------------------------------------
        # Music Player — Gapless
        # -----------------------------------------------------------------------
        "audio/mpeg"   = "com.github.neithern.g4music.desktop";
        "audio/ogg"    = "com.github.neithern.g4music.desktop";
        "audio/flac"   = "com.github.neithern.g4music.desktop";
        "audio/x-flac" = "com.github.neithern.g4music.desktop";
        "audio/wav"    = "com.github.neithern.g4music.desktop";
        "audio/x-wav"  = "com.github.neithern.g4music.desktop";
        "audio/mp4"    = "com.github.neithern.g4music.desktop";
        "audio/aac"    = "com.github.neithern.g4music.desktop";
        "audio/x-m4a"  = "com.github.neithern.g4music.desktop";
        "audio/opus"   = "com.github.neithern.g4music.desktop";
        "audio/webm"   = "com.github.neithern.g4music.desktop";

        # -----------------------------------------------------------------------
        # Document Viewer — Papers
        # -----------------------------------------------------------------------
        "application/pdf"               = "org.gnome.Papers.desktop";
        "application/x-pdf"             = "org.gnome.Papers.desktop";
        "image/vnd.djvu"                = "org.gnome.Papers.desktop";
        "image/vnd.djvu+multipage"      = "org.gnome.Papers.desktop";
        "application/epub+zip"          = "org.gnome.Papers.desktop";
        "application/vnd.comicbook+zip" = "org.gnome.Papers.desktop";
        "application/x-cbz"             = "org.gnome.Papers.desktop";
        "application/x-cbr"             = "org.gnome.Papers.desktop";

        # -----------------------------------------------------------------------
        # Text Editor — Neovim (fallback, lowest priority)
        # Overridden by VSCodium (plain) or Zed (mkForce) when installed.
        # -----------------------------------------------------------------------
        "text/plain"             = lib.mkDefault "nvim.desktop";
        "application/json"       = lib.mkDefault "nvim.desktop";
        "application/x-yaml"     = lib.mkDefault "nvim.desktop";
        "application/toml"       = lib.mkDefault "nvim.desktop";
        "application/x-shellscript" = lib.mkDefault "nvim.desktop";
        "text/x-shellscript"     = lib.mkDefault "nvim.desktop";
      };
    };

    # Neovim desktop entry — opens in Kitty (available on all graphical hosts)
    xdg.desktopEntries.nvim = {
      name        = "Neovim";
      genericName = "Text Editor";
      comment     = "Hyperextensible Vim-based text editor";
      exec        = "kitty nvim %F";
      terminal    = false;
      categories  = [ "Utility" "TextEditor" ];
      icon        = "nvim";
      mimeType    = [
        "text/plain"
        "application/json"
        "application/x-yaml"
        "application/toml"
        "application/x-shellscript"
        "text/x-shellscript"
      ];
    };

    # Allow HM to take ownership of mimeapps.list even if it was previously
    # edited manually. Without this, HM silently skips the file.
    xdg.configFile."mimeapps.list".force = true;
  }];

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts               # Wide unicode coverage, clean and readable
      noto-fonts-cjk-sans      # Chinese, Japanese, Korean support
      liberation_ttf           # Free replacements for Arial, Times New Roman etc
      # noto-fonts-color-emoji intentionally omitted — it steals the
      # private-use-area codepoints that Nerd Fonts uses for icons,
      # breaking fastfetch and terminal icon rendering.
      # Nerd Fonts (all families) are already installed via system/core.
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
