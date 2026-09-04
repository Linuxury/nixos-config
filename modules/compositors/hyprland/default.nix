# ===========================================================================
# modules/compositors/hyprland/default.nix — Hyprland Wayland Compositor
#
# Hyprland is a dynamic tiling Wayland compositor with smooth animations
# and extensive customization potential.
#
# Shell layer and greeter are separate — import them in your host config:
#   modules/shells/wayle/default.nix     # Wayle (needs greeters/sddm)
#   modules/shells/noctalia/default.nix  # Noctalia (needs greeters/sddm)
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ pkgs, lib, ... }:

let
  # Wrapper that launches the UWSM-managed Hyprland session with stdout/stderr
  # redirected to the journal. Without this, UWSM prints session-init messages
  # directly to the TTY, causing a brief flash of text on a blank screen between
  # the greeter exiting and Hyprland's first frame appearing.
  hyprland-session-start = pkgs.writeShellScript "hyprland-session-start" ''
    exec ${pkgs.systemd}/bin/systemd-cat -t hyprland-session \
      uwsm start hyprland-uwsm.desktop
  '';

  hyprland-session-pkg = pkgs.runCommand "hyprland-session"
    { passthru.providedSessions = [ "hyprland-session" ]; }
    ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/hyprland-session.desktop <<'EOF'
      [Desktop Entry]
      Name=Hyprland (quiet)
      Comment=Hyprland Wayland Compositor (UWSM, log suppressed)
      Exec=${hyprland-session-start}
      Type=Application
      DesktopNames=Hyprland
      Keywords=wayland;compositor;tiling
      EOF
    '';

in

{
  imports = [
    # Desktop components (bar, launcher, notifications) are compositor-agnostic.
    # Import them in your host config from modules/components/:
    #   modules/components/bar/waybar/default.nix           — waybar
    #   modules/components/launcher/wofi/default.nix        — wofi + rofi
    #   modules/components/notifications/swaync/default.nix — swaync
  ];

  # Switch SDDM greeter compositor from Weston to KWin: Weston never sends a
  # pointer capability for the keyboard-dongle devices (Keychron Ultra-Link,
  # Lemokey Link), so Qt never creates a wl_pointer and the cursor is
  # invisible regardless of theme. KWin advertises pointer capability
  # correctly for these devices and natively supports layer-shell-qt, which
  # makes QT_WAYLAND_SHELL_INTEGRATION=layer-shell actually work.
  services.displayManager.sddm.wayland.compositor = "kwin";

  # Override the NixOS kwin GreeterEnvironment (which only sets layer-shell)
  # with our complete set. lib.mkForce wins over the NixOS module's plain
  # assignment so all vars are present.
  services.displayManager.sddm.settings.General.GreeterEnvironment = lib.mkForce
    "QT_QPA_PLATFORM=wayland,QT_QPA_PLATFORMTHEME=,QT_WAYLAND_SHELL_INTEGRATION=layer-shell,XCURSOR_THEME=BreezeX-Light,XCURSOR_SIZE=24,XCURSOR_PATH=/run/current-system/sw/share/icons,XDG_DATA_DIRS=/run/current-system/sw/share";

  # KWin (SDDM's compositor) manages its seat via logind directly, not seatd.
  # Hyprland's aquamarine backend tries seatd first, then logind — but with
  # KWin already holding the DRM device via logind, seatd can never start,
  # so aquamarine's seatd attempts just crash-loop. Forcing the logind
  # backend makes both compositors share the same seat, as intended.
  #
  # seatd itself must be disabled too: greeters/sddm enables it, but it can
  # never acquire the DRM device here, so it blocks graphical.target (and
  # UWSM) for its full 90s startup timeout before Hyprland can launch.
  environment.sessionVariables.LIBSEAT_BACKEND = "logind";
  # Force Kvantum as the Qt style engine on Hyprland — overrides the default
  # fusion/windowsvista style so Qt apps pick up the matugen color palette.
  # Scoped here so COSMIC/KDE hosts are unaffected (they manage Qt theming themselves).
  environment.sessionVariables.QT_STYLE_OVERRIDE = "kvantum";
  services.seatd.enable = lib.mkForce false;

  services.displayManager.sddm.settings.Theme = {
    CursorTheme = "BreezeX-Light";
    CursorSize  = "24";
  };

  # Keep tmpfiles symlinks for sddm user home so libXcursor finds BreezeX-Light
  # via the home dir path (~/.icons) in addition to XCURSOR_PATH.
  systemd.tmpfiles.rules = [
    "L /var/lib/sddm/.icons/BreezeX-Light            - - - - /run/current-system/sw/share/icons/BreezeX-Light"
    "L /var/lib/sddm/.local/share/icons/BreezeX-Light - - - - /run/current-system/sw/share/icons/BreezeX-Light"
  ];

  # =========================================================================
  # Shared Home Manager modules — injected into every user on this host.
  # These are compositor-level concerns, not shell-specific.
  # =========================================================================
  home-manager.sharedModules = [
    ./themes/default.nix                          # BreezeX-Light cursor + Tela-dark icons + GTK
    ./matugen/default.nix                          # matugen color sync on wallpaper change
    {
      # Kitty — Hyprland handles transparency/blur; disable Kitty's own settings
      home.file.".config/kitty/hyprland-overrides.conf".source =
        ../../../dotfiles/kitty/hyprland-overrides.conf;
    }
  ];

  # nautilus-bookmarks hardcodes /home/linuxury/ paths — scope to linuxury only.
  home-manager.users.linuxury = {
    imports = [ ../../system/graphical/nautilus/default.nix ];
  };

  # =========================================================================
  # Hyprland — the compositor itself
  #
  # withUWSM wraps Hyprland in the Universal Wayland Session Manager,
  # which handles systemd session integration properly.
  # =========================================================================
  programs.hyprland = {
    enable      = true;
    withUWSM    = true;
    xwayland.enable = true;
  };

  # =========================================================================
  # XDG Portal for Hyprland
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # Register the quiet session wrapper so greeters can offer it.
  services.displayManager.sessionPackages = [ hyprland-session-pkg ];

  # =========================================================================
  # Polkit — Authentication agent
  # =========================================================================
  security.polkit.enable = true;

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # GNOME Keyring works fine outside of GNOME.
  # PAM integration: login/TTY fallback always present here.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # =========================================================================
  # Hyprland companion tools
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Quiet UWSM session wrapper — services.displayManager.sessionPackages
    # (below) only reaches SDDM's own session-file provider; greetd-based
    # greeters (noctalia-greeter) scan /run/current-system/sw/share directly,
    # which is populated from environment.systemPackages. Needs to be listed
    # here too or it never appears in a greetd session picker.
    hyprland-session-pkg

    # Cursor theme — installed system-wide so SDDM greeter picks it up
    pkgs.breezex-cursors

    # Screenshots
    grim            # Screenshot tool for Wayland
    slurp           # Region selector (used with grim)
    hyprpicker      # Freezes screen during screenshot selection
    satty           # Screenshot annotation tool

    # Screen recording
    # wf-recorder 0.6.0 fails to build against current nixpkgs ffmpeg — sample_fmts
    # was removed from AVCodec upstream (2026-08-13). Re-enable once nixpkgs fixes/bumps it.
    # wf-recorder     # Wayland screen recorder (lightweight, keybind toggle)
    wl-screenrec    # GPU-accelerated screen recorder (AMD/NVIDIA)

    # Night light
    wlsunset        # Wayland color temperature filter (auto sunset/sunrise)

    # Clipboard
    wl-clipboard    # Wayland clipboard (wl-copy / wl-paste commands)
    cliphist        # Clipboard history manager

    # Idle management — locking now goes through `noctalia msg session lock`
    hypridle        # Idle management (dim, lock, suspend)

    # Audio
    pavucontrol     # PulseAudio volume mixer GUI

    # Notifications (for scripts/apps that call notify-send)
    libnotify

    # Theming
    nwg-look                              # GTK theme settings for Wayland compositors
    qt6Packages.qt6ct                     # Qt6 theme settings outside of KDE/GNOME
    kdePackages.qtstyleplugin-kvantum     # Kvantum style engine — lets Qt apps follow the matugen palette

    # Polkit authentication agent
    polkit_gnome

    # Brightness control — required for laptop brightness keybinds
    brightnessctl

    # File manager — Nautilus (GNOME Files)
    nautilus
    sushi           # Quick file preview — press Space on any file
    tinysparql      # Tracker3 — provides org.freedesktop.Tracker3 for Nautilus search
    localsearch     # Tracker miners (filesystem crawler)

    # Media key control — playerctl play/pause/next/prev keybinds
    playerctl

    # IPC event listener — used by scripts watching Hyprland socket events
    socat
  ];

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable = true;
}
