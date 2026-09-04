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

  # hyprlock needs this to authenticate with the user's password. hyprlock
  # itself is protocol-based (ext-session-lock-v1, confirmed from Umbriel's
  # own docs — see docs/user/security.md and configuration.md's idle
  # inhibition section), not Hyprland-exclusive, same as hyprpicker.
  security.pam.services.hyprlock = {};

  # =========================================================================
  # Shared Home Manager modules — injected into every user on this host.
  # These are compositor-level concerns, not shell-specific.
  # =========================================================================
  home-manager.sharedModules = [
    ./themes/default.nix    # BreezeX-Light cursor + Tela-dark icons + GTK + Kvantum/qt6ct
    ../../themes/matugen/default.nix  # matugen color sync (Kvantum only — everything else is Noctalia-native)
    ./noctalia-bridge/default.nix  # remaps Noctalia's umbriel theme keys to Umbriel's real schema (upstream mismatch)

    ({ config, ... }: {
      # =====================================================================
      # Umbriel's own config — real dotfiles, not a generated Nix attrset.
      #
      # ~/.config/umbriel is a live symlink into dotfiles/umbriel/ (same
      # mkOutOfStoreSymlink pattern as dotfiles/hypr/) — edits in the repo
      # take effect immediately, matched by Umbriel's own live-reload.
      # config.toml there splits into general.toml/keybinds.toml/
      # outputs.toml via Umbriel's own [include] mechanism (docs/user/
      # configuration.md), plus noctalia-fixed.toml (gitignored, generated
      # by ./noctalia-bridge on every wallpaper change).
      #
      # No more automatic `umbriel validate` at build time (that came from
      # HM's programs.umbriel.settings, no longer used) — run it by hand
      # after editing: `umbriel validate -c ~/.config/umbriel/config.toml`.
      # =====================================================================
      home.file.".config/umbriel".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/umbriel";
    })
  ];

  # =========================================================================
  # Umbriel companion tools — compositor-agnostic subset of the Hyprland
  # toolset. hyprlock/hypridle confirmed protocol-based (ext-session-lock-v1
  # / ext-idle-notify-v1), not Hyprland-exclusive, same as hyprpicker.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Cursor theme — installed system-wide so the greeter picks it up
    breezex-cursors

    # Screenshots
    grim
    slurp
    satty
    hyprpicker  # freeze-overlay during area selection — protocol-based, not Hyprland-only

    # Screen lock / idle management
    hyprlock
    hypridle

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
