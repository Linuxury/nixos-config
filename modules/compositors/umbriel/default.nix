# ===========================================================================
# modules/compositors/umbriel/default.nix — Umbriel Wayland Compositor
#
# Umbriel is noctalia-dev's independent wlroots compositor (scrolling,
# dwindle, and master layouts) — a sibling project to Noctalia Shell and
# noctalia-greeter, designed to pair with Noctalia as an alternative to
# Hyprland.
#
# Package, session-picker registration (services.displayManager.sessionPackages),
# systemd service, and xdg.portal wiring are ALL handled automatically by
# inputs.umbriel.nixosModules.default once programs.umbriel.enable = true —
# no UWSM wrapper or greeter-compositor override needed here (unlike
# Hyprland's KWin-for-SDDM workaround): noctalia-greeter runs its own
# bundled wlroots compositor regardless of which session compositor is
# picked.
#
# Shell layer: pair with modules/shells/noctalia/default.nix, same as
# Hyprland. Import this module in a host config to make it selectable.
# ===========================================================================

{ inputs, pkgs, ... }:

{
  imports = [ inputs.umbriel.nixosModules.default ];

  programs.umbriel.enable = true;
  # package self-defaults via the flake's withDefaultPackage wrapper —
  # no override needed.

  # =========================================================================
  # Polkit — Authentication agent
  # =========================================================================
  security.polkit.enable = true;

  # =========================================================================
  # Keyring — Secret storage for apps (GNOME Keyring works fine outside GNOME)
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # =========================================================================
  # Shared Home Manager modules — injected into every user on this host.
  # These are compositor-level concerns, not shell-specific.
  # =========================================================================
  home-manager.sharedModules = [
    inputs.umbriel.homeModules.default  # programs.umbriel HM options (settings -> config.toml)
    ./themes/default.nix    # BreezeX-Light cursor + Tela-dark icons + GTK + Kvantum/qt6ct
    ./matugen/default.nix   # matugen color sync on wallpaper change

    ({ ... }: {
      # =====================================================================
      # Umbriel's own config — HM's programs.umbriel.settings (attrset → TOML,
      # validated at build time via `umbriel validate`).
      #
      # Everything not set here stays on Umbriel's documented built-ins
      # (focus nav, workspace switching, fullscreen, floating toggle, etc.
      # all ship enabled by default — see upstream examples/config.toml).
      # Only the 3 real custom bindings from dotfiles/hypr/modules/keybinds.lua
      # are ported here, to keep muscle memory consistent with Hyprland.
      # =====================================================================
      programs.umbriel = {
        enable = true;

        settings = {
          general.autostart = [ "noctalia" ];

          # matugen writes [colors]/[colors.border] here on wallpaper change
          # (see matugen/default.nix) — Umbriel applies included files live,
          # no reload command needed.
          include.files = [ "matugen-colors.toml" ];

          keybinds = {
            "Mod+Return"       = "spawn:kitty";
            "Mod+Shift+Return" = "spawn:kitty --class floating-term";
            "Mod+Space"        = "spawn:noctalia msg panel-toggle launcher";
          };
        };
      };
    })
  ];

  # =========================================================================
  # Umbriel companion tools — compositor-agnostic subset of the Hyprland
  # toolset. hyprlock/hypridle are skipped: Umbriel needs its own idle/lock
  # story, deferred until it's actually running to test against.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Cursor theme — installed system-wide so the greeter picks it up
    breezex-cursors

    # Screenshots
    grim
    slurp
    satty

    # Screen recording
    wl-screenrec

    # Night light
    wlsunset

    # Clipboard
    wl-clipboard
    cliphist

    # Audio
    pavucontrol

    # Notifications
    libnotify

    # Theming
    nwg-look
    qt6Packages.qt6ct
    kdePackages.qtstyleplugin-kvantum

    # Polkit authentication agent
    polkit_gnome

    # Brightness control
    brightnessctl

    # File manager — Nautilus
    nautilus
    sushi
    tinysparql
    localsearch

    # Media keys
    playerctl

    # IPC / scripting
    socat
  ];

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable = true;
}
