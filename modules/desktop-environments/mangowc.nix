# ===========================================================================
# modules/desktop-environments/mangowc.nix — MangoWC + Noctalia Shell
#
# MangoWC is a lightweight wlroots/scenefx-based Wayland compositor.
# Noctalia is the shell layer: bar, launcher, notifications, widgets.
#
# Login screen: greetd backend + tuigreet frontend (TUI, runs on TTY directly
# — no Wayland compositor needed for the greeter, avoids cage SIGABRT on RDNA3).
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  # Wrapper that sets cursor env vars before exec-ing MangoWC.
  # greetd launches this directly, so MangoWC inherits XCURSOR_THEME
  # at startup (before systemd environment.d is sourced — too late otherwise).
  mangowc-start = pkgs.writeShellScript "mangowc-start" ''
    # === DUAL LOGGING: journal (always) + file (persistent) ===
    # Journal survives rollbacks and is readable without booting into the gen.
    # File captures everything including MangoWC stderr.
    LOG="/home/linuxury/.local/share/mangowc-session.log"
    mkdir -p "/home/linuxury/.local/share"
    # Redirect all further stdout+stderr to the log file.
    exec 1>>"$LOG" 2>&1

    # Also write a copy of the startup env to the journal (survives if file fails).
    {
      echo "=== mangowc-start $(date) ==="
      echo "XDG_SESSION_ID=''${XDG_SESSION_ID:-UNSET}"
      echo "XDG_VTNR=''${XDG_VTNR:-UNSET}"
      echo "HOME=''${HOME:-UNSET}"
      echo "VT_ACTIVE=$(cat /sys/class/tty/tty0/active 2>/dev/null || echo unknown)"
    } | /run/current-system/sw/bin/systemd-cat -t mangowc-start 2>/dev/null || true

    echo "=== $(date) ==="
    echo "XDG_SESSION_ID=''${XDG_SESSION_ID:-UNSET}"
    echo "XDG_VTNR=''${XDG_VTNR:-UNSET}"
    echo "VT_ACTIVE=$(cat /sys/class/tty/tty0/active 2>/dev/null || echo unknown)"

    export XCURSOR_THEME=BreezeX-Light
    export XCURSOR_SIZE=24
    # On UEFI systems, simpledrm (EFI framebuffer) claims card0 before amdgpu.
    # wlroots enumerates DRM devices and picks the first one — card0 — which has
    # no GPU acceleration and may not be connected to any physical output.
    # Pin MangoWC to card1 (amdgpu) so it renders on the actual GPU.
    export WLR_DRM_DEVICES=/dev/dri/card1

    # Poll VT until active (or give up after 3s) — VT switch is async.
    if [ -n "''${XDG_SESSION_ID:-}" ] && [ -n "''${XDG_VTNR:-}" ]; then
      /run/current-system/sw/bin/loginctl activate "$XDG_SESSION_ID" || true
      for i in $(seq 1 30); do
        active=$(cat /sys/class/tty/tty0/active 2>/dev/null || echo "unknown")
        echo "VT poll $i: active=$active want=tty''${XDG_VTNR}"
        [ "$active" = "tty''${XDG_VTNR}" ] && break
        sleep 0.1
      done
    else
      echo "WARNING: XDG_SESSION_ID or XDG_VTNR not set — skipping VT activation"
    fi

    echo "Launching MangoWC..."
    exec ${pkgs.mangowc}/bin/mango
  '';

  # Session .desktop — registers MangoWC with SDDM's session picker.
  # passthru.providedSessions is required by services.displayManager.sessionPackages.
  mangowc-session = (pkgs.writeTextDir "share/wayland-sessions/mangowc.desktop" ''
    [Desktop Entry]
    Name=MangoWC
    Comment=Lightweight Wayland Compositor (MangoWC + Noctalia)
    Exec=${mangowc-start}
    Type=Application
    DesktopNames=MangoWC
    Keywords=wayland;compositor;tiling
  '').overrideAttrs (_: { passthru.providedSessions = [ "mangowc" ]; });
in

{
  imports = [
    ../greeters/sddm-catppuccin.nix  # SDDM + Catppuccin Mocha/Mauve login screen
  ];

  # =========================================================================
  # Shared Home Manager modules — cursor, icons, GTK theme, Nautilus extras
  #
  # Injected into every user on this host via sharedModules so all users
  # inherit the same cursor, icon theme, and Nautilus bookmarks/scripts
  # without duplicating config per-user.
  # =========================================================================
  home-manager.sharedModules = [
    ../home/mangowc-theme.nix      # BreezeX-Light cursor + Tela-dark icons + adw-gtk3-dark
    ../home/nautilus-bookmarks.nix # Sidebar bookmarks + right-click Copy Path / Open as Root
  ];

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  #
  # tinysparql (Tracker3) provides the org.freedesktop.Tracker3 DBus service
  # that Nautilus queries when you search. localsearch crawls the filesystem
  # and feeds results into Tracker's SPARQL store.
  # Without these, Nautilus search returns no results.
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable  = true;

  # =========================================================================
  # Nix binary cache — pre-built Noctalia binaries (avoids local Qt compile)
  #
  # Noctalia publishes all packages to Cachix. Without this the first build
  # would recompile Quickshell and its Qt dependencies from source (~30 min).
  # =========================================================================
  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # =========================================================================
  # Login manager — SDDM + Catppuccin Mocha/Mauve (via sddm-catppuccin.nix)
  #
  # SDDM runs in Wayland mode using weston as the greeter compositor.
  # weston is lightweight and GPU-agnostic — avoids the cage SIGABRT on RDNA3
  # (RX 7900 XTX) that blocked cage-based greeters (qtgreet, regreet).
  # =========================================================================

  # Register MangoWC as a selectable session in SDDM.
  # services.displayManager.sessionPackages feeds into SDDM's SessionDir —
  # different from environment.systemPackages which tuigreet used to scan.
  services.displayManager.sessionPackages = [ mangowc-session ];

  # On UEFI systems the EFI simple framebuffer registers as DRM minor 0 (card0),
  # pushing amdgpu to minor 1 (card1). Weston defaults to card0, gets a
  # non-accelerated stub that can't render, and dies immediately → black screen.
  # Force card1 so the greeter compositor runs on the actual GPU.
  # Drops the auto-generated weston.ini (libinput/xkb defaults are fine for
  # a login screen).
  # XCURSOR_THEME/SIZE: weston uses these for its hardware cursor layer (DRM
  # plane cursor). Without them weston renders a blank hardware cursor on top
  # of the Qt greeter's own invisible cursor → doubly invisible.
  # XCURSOR_PATH: xcursor defaults to /usr/share/icons which doesn't exist on
  # NixOS. Must be set explicitly so weston can resolve XCURSOR_THEME=Adwaita.
  # Note: GreeterEnvironment (in sddm-catppuccin.nix) also sets XCURSOR_PATH
  # for the Qt greeter process — both need it as they are separate env contexts.
  services.displayManager.sddm.settings.Wayland.CompositorCommand = lib.mkForce
    "env XCURSOR_THEME=Adwaita XCURSOR_SIZE=24 XCURSOR_PATH=/run/current-system/sw/share/icons ${pkgs.weston}/bin/weston --shell=kiosk --drm-device=card1";

  # =========================================================================
  # XDG Desktop Portal — screen capture, file picker, screenshots, etc.
  #
  # xdg-desktop-portal-wlr handles wlroots-based compositors (MangoWC).
  # xdg-desktop-portal-gtk handles file pickers and GTK app integration.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "wlr";
  };

  # =========================================================================
  # Polkit — privilege escalation for GUI apps (mount drives, etc.)
  # =========================================================================
  security.polkit.enable = true;

  # =========================================================================
  # Keyring — secret storage for apps (browser passwords, SSH keys, etc.)
  # Unlocked automatically on login via PAM integration in sddm-catppuccin.nix.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;

  # =========================================================================
  # Bluetooth — desktop always-on (no suspend needed on desktop)
  # =========================================================================
  hardware.bluetooth = {
    powerOnBoot = true;
    settings = {
      General.FastConnectable = true;
      Policy.AutoEnable = true;
    };
  };

  # Workaround: cheap USB BT dongles (e.g. Actions 10d7:b012) don't fully
  # support BlueZ MGMT commands, causing "Failed to set default system config"
  # and leaving the adapter powered off despite AutoEnable=true. This service
  # explicitly powers on the adapter after it has had time to settle.
  systemd.services.bluetooth-power-on = {
    description = "Force-power Bluetooth adapter on";
    after = [ "bluetooth.service" ];
    requires = [ "bluetooth.service" ];
    wantedBy = [ "bluetooth.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      ExecStart = "${pkgs.bluez}/bin/bluetoothctl power on";
      RemainAfterExit = true;
    };
  };

  # =========================================================================
  # Packages — compositor, shell layer, and companion tools
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # -----------------------------------------------------------------------
    # Compositor + shell
    # -----------------------------------------------------------------------
    mangowc           # Wayland compositor (wlroots + scenefx based)
    noctalia-shell    # Shell layer: bar, launcher, notifications, widgets
    noctalia-qs       # Quickshell-based QtQuick toolkit used by noctalia-shell

    # Session .desktop (registers MangoWC in QtGreet's session list)
    mangowc-session

    # -----------------------------------------------------------------------
    # Screenshots
    # -----------------------------------------------------------------------
    grim              # Screenshot tool for Wayland
    slurp             # Region selector (used with grim)
    swappy            # Screenshot annotation tool

    # -----------------------------------------------------------------------
    # Screen recording
    # -----------------------------------------------------------------------
    wf-recorder       # Wayland screen recorder (lightweight, keybind toggle)
    wl-screenrec      # GPU-accelerated screen recorder (AMD/NVIDIA)

    # -----------------------------------------------------------------------
    # Night light / color temperature
    # -----------------------------------------------------------------------
    wlsunset          # Auto sunset/sunrise color temperature filter

    # -----------------------------------------------------------------------
    # Clipboard
    # -----------------------------------------------------------------------
    wl-clipboard      # wl-copy / wl-paste commands
    cliphist          # Clipboard history manager

    # -----------------------------------------------------------------------
    # Screen locking + idle management
    # -----------------------------------------------------------------------
    swaylock               # Wayland-native screen locker (works on any wlroots WM)
    swayidle               # Idle daemon — triggers lock/DPMS; respects Wayland idle-inhibit
    sway-audio-idle-inhibit # Inhibits idle while audio plays — keeps screen on during games

    # -----------------------------------------------------------------------
    # Audio
    # -----------------------------------------------------------------------
    pavucontrol       # PulseAudio volume mixer GUI

    # -----------------------------------------------------------------------
    # Notifications
    # -----------------------------------------------------------------------
    libnotify         # notify-send command for scripts/apps

    # -----------------------------------------------------------------------
    # Theming
    # -----------------------------------------------------------------------
    nwg-look           # GTK theme settings for Wayland compositors
    qt6Packages.qt6ct  # Qt6 theme settings outside of KDE/GNOME

    # -----------------------------------------------------------------------
    # File manager
    # -----------------------------------------------------------------------
    nautilus              # GNOME Files — graphical file manager
    sushi                 # Quick file preview — press Space on a file in Nautilus
    tinysparql            # Tracker3 — org.freedesktop.Tracker3 for Nautilus search
    localsearch           # Tracker miners — filesystem crawler that feeds Tracker

    # -----------------------------------------------------------------------
    # IPC / scripting
    # -----------------------------------------------------------------------
    socat                 # Socket relay — used by scripts watching compositor events

    # -----------------------------------------------------------------------
    # System tray / applets
    # -----------------------------------------------------------------------
    networkmanagerapplet  # WiFi tray icon
    blueman               # Bluetooth manager with tray icon
    polkit_gnome          # Polkit authentication agent

    # -----------------------------------------------------------------------
    # Media / brightness
    # -----------------------------------------------------------------------
    playerctl             # Media key control (play/pause/next/prev)
    brightnessctl         # Monitor brightness control

    # -----------------------------------------------------------------------
    # Output management
    # -----------------------------------------------------------------------
    wlr-randr             # wlroots output tool — sets resolution, refresh rate, VRR
  ];
}
