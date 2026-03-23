# ===========================================================================
# modules/desktop-environments/hyprland.nix — Hyprland Wayland Compositor
#
# Hyprland is a dynamic tiling Wayland compositor with smooth animations
# and a lot of customization potential. It's not a full DE like COSMIC or
# KDE — it's just a window manager, so you build the rest of the experience
# yourself (bar, launcher, notifications, etc).
#
# This module is ONLY enabled on your machines (linuxury).
# It's a learning/experimentation environment, not a daily driver yet.
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ config, pkgs, inputs, ... }:

let
  # BreezeX cursor theme — same derivation as cosmic-theme.nix
  # The greeter user has no home-manager, so we install it system-wide
  breezex-cursors = pkgs.stdenv.mkDerivation {
    pname   = "breezex-cursor-theme";
    version = "2.0.1";
    src = pkgs.fetchzip {
      url       = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX.tar.xz";
      sha256    = "10fbvbls52cgp5kshlcxbh3nqarh2mwhpj0w5kkk4hrl3sdc1bcj";
      stripRoot = false;
    };
    dontBuild     = true;
    dontConfigure = true;
    installPhase  = ''
      mkdir -p $out/share/icons
      cp -r . $out/share/icons/
    '';
  };
in

{
  # =========================================================================
  # Inject hypr-matugen into every user's Home Manager config
  # =========================================================================
  home-manager.sharedModules = [
    ../services/hypr-matugen.nix
    ../home/cosmic-theme.nix   # BreezeX-Light cursor + Tela-dark icons
    {
      # Kitty — Hyprland handles transparency/blur, disable Kitty's own settings
      home.file.".config/kitty/hyprland-overrides.conf".source =
        ../../dotfiles/kitty/hyprland-overrides.conf;
    }
  ];
  # =========================================================================
  # Hyprland — the compositor itself
  #
  # NixOS has a dedicated Hyprland module that handles all the Wayland
  # plumbing automatically. We just enable it.
  #
  # withUWSM wraps Hyprland in the Universal Wayland Session Manager,
  # which handles systemd session integration properly — recommended
  # for NixOS specifically.
  # =========================================================================
  programs.hyprland = {
    enable = true;
    withUWSM = true;   # Proper systemd session integration
    xwayland.enable = true; # Allows running X11 apps inside Hyprland
  };

  # =========================================================================
  # XDG Portal for Hyprland
  #
  # Hyprland uses xdg-desktop-portal-hyprland for screen sharing,
  # file pickers, and other desktop integration features.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk  # Fallback for GTK apps
    ];
    config.common.default = "hyprland";
  };

  # =========================================================================
  # Polkit — Authentication agent
  #
  # Without a polkit agent, GUI apps can't ask for your password when
  # they need elevated permissions (e.g. mounting drives, system settings).
  # Hyprland doesn't include one by default unlike full DEs.
  # =========================================================================
  security.polkit.enable = true;

  # PAM — hyprlock needs this to authenticate with user password
  security.pam.services.hyprlock = {};

  # =========================================================================
  # Hyprland companion tools
  #
  # Since Hyprland is just a compositor, you need to bring your own
  # tools for everything else. These are the building blocks —
  # actual configuration of each lives in your dotfiles.
  #
  # Think of this as the toolkit. You decide how to use them.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Cursor theme — needed by SDDM greeter (no home-manager at login)
    breezex-cursors

    # Status bar
    waybar          # Highly customizable Wayland bar

    # Launchers
    wofi            # App launcher / dmenu replacement for Wayland
    rofi            # Alternative launcher with more features (rofi-wayland merged into rofi)

    # Notifications
    swaynotificationcenter  # Sway Notification Center — notification daemon + panel
    libnotify               # notify-send — sends notifications from scripts/apps

    # Wallpaper
    swww            # Animated wallpaper daemon (swww-daemon + swww img)

    # Screenshots
    grim            # Screenshot tool for Wayland
    slurp           # Region selector (used with grim)
    swappy          # Screenshot annotation tool

    # Screen recording
    wf-recorder     # Wayland screen recorder (lightweight, keybind toggle)
    wl-screenrec    # GPU-accelerated screen recorder (AMD/NVIDIA)

    # Night light
    wlsunset        # Wayland color temperature filter (auto sunset/sunrise)

    # Clipboard
    wl-clipboard    # Wayland clipboard (wl-copy / wl-paste commands)
    cliphist        # Clipboard history manager

    # Screen locking
    hyprlock        # Hyprland-native screen locker
    hypridle        # Idle management (dim, lock, suspend)

    # Audio
    pavucontrol     # PulseAudio volume mixer GUI
    swayosd         # Center-bottom OSD layer-shell window for volume/brightness

    # Theming
    nwg-look        # GTK theme settings for Wayland compositors
    qt6Packages.qt6ct  # Qt6 theme settings outside of KDE/GNOME

    # System tray / applets
    networkmanagerapplet  # WiFi tray icon
    blueman               # Bluetooth manager with tray icon

    # Polkit authentication agent
    # Lets GUI apps request elevated permissions (mount drives, etc.)
    # Autostarted via autostart.conf — must be in packages so the binary exists.
    polkit_gnome

    # Brightness control — required for laptop brightness keybinds
    brightnessctl

    # File managers
    nemo            # GUI file manager — GTK3, Nautilus fork, uses gvfs for smb:// shares
                    # Nautilus 47+ broke on non-Mutter compositors (org.gnome.Mutter.ServiceChannel)
                    # Nemo is the closest alternative: same GVfs/SMB backend, dual pane, Hyprland-safe
                    # gvfs + samba already enabled in graphical-base.nix

    # Quickshell — Qt6/QML desktop shell toolkit
    # Used to build the custom shell: bar, dock, launcher, notifications, OSD,
    # sidebar, workspace overview, and lock screen.
    # Flake input declared in flake.nix with nixpkgs.follows for Qt version safety.
    inputs.quickshell.packages.${pkgs.system}.default
    qt6Packages.qt5compat  # Qt5 compat layer — enables Gaussian blur effects in Quickshell

    # Media key control — playerctl play/pause/next/prev keybinds
    playerctl

    # SDDM — pixie-sddm theme (Material Design 3 greeter)
    # User avatar is injected as assets/avatar.jpg so the theme picks it up
    # as the fallback without relying on AccountsService D-Bus at boot.
    (let avatar = ../../assets/Avatar/linuxury.jpg;
    in pkgs.stdenv.mkDerivation {
      name = "pixie-sddm";
      src = pkgs.fetchFromGitHub {
        owner  = "xCaptaiN09";
        repo   = "pixie-sddm";
        rev    = "main";
        sha256 = "sha256-lmE/49ySuAZDh5xLochWqfSw9qWrIV+fYaK5T2Ckck8=";
      };
      installPhase = ''
        mkdir -p $out/share/sddm/themes/pixie
        cp -r * $out/share/sddm/themes/pixie/
        cp ${avatar} $out/share/sddm/themes/pixie/assets/avatar.jpg
      '';
    })
    # SDDM wallpaper — packaged from assets so it's available in the Nix store
    (let wallpaper = builtins.path {
          path = ../../assets/Wallpapers/4k;
          name = "sddm-wallpapers";
        };
    in pkgs.stdenvNoCC.mkDerivation {
      name = "sddm-wallpaper";
      src = wallpaper;
      dontUnpack = false;
      installPhase = ''
        mkdir -p $out/share/sddm/wallpapers
        cp "4k - 01.jpg" $out/share/sddm/wallpapers/background.jpg
      '';
    })
    # theme.conf.user override for pixie-sddm — sets wallpaper + colors
    (pkgs.writeTextDir "share/sddm/themes/pixie/theme.conf.user" ''
      [General]
      background=/run/current-system/sw/share/sddm/wallpapers/background.jpg
      primaryColor=#E3E3DC
      accentColor=#A9C78F
      backgroundColor=#1A1C18
      textColor=#E3E3DC
    '')
    kdePackages.qtdeclarative
    kdePackages.qtsvg
  ];

  # =========================================================================
  # Bluetooth — enabled here because Hyprland needs blueman for tray control
  # On COSMIC and KDE this is handled by the DE itself.
  # =========================================================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # Bluetooth on automatically at startup
    settings = {
      General = {
        FastConnectable = true;    # Quick reconnect to known devices
        AutoEnable = true;         # Enable adapter on boot
      };
      Policy = {
        AutoEnable = true;         # Auto-connect trusted devices
      };
    };
  };
  services.blueman.enable = true;

  # =========================================================================
  # Display Manager — SDDM + pixie-sddm theme
  #
  # Material Design 3 inspired greeter with stacked clock and dark UI.
  # Qt6 native, supports wallpaper background.
  # =========================================================================

  services.displayManager.sddm = {
    enable  = true;
    theme   = "pixie";
    package = pkgs.kdePackages.sddm;
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    extraPackages = with pkgs; [
      kdePackages.layer-shell-qt  # Required for kwin greeter layer-shell support
    ];
    settings = {
      General = {
        GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
      };
      Theme = {
        CursorTheme = "BreezeX-Light";
        CursorSize  = 24;
      };
      Services = {
        Enable = true;
      };
    };
  };

  # =========================================================================
  # AccountsService — User avatar + metadata for SDDM greeter
  #
  # SDDM reads user icons from AccountsService. Without this daemon,
  # the greeter shows a default silhouette instead of the real profile photo.
  # The activation script in linuxury-description.nix copies the avatar and
  # writes the user config file.
  # =========================================================================
  services.accounts-daemon.enable = true;

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # Without a keyring, apps like browsers and SSH agents lose saved
  # passwords on every reboot. GNOME Keyring works fine outside of GNOME.
  # SDDM handles the PAM login so we enable the keyring unlock there.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
}
