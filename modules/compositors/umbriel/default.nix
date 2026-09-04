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
      # Umbriel built-ins (active without any config): Mod+H/J/K/L focus,
      # Mod+Shift+Arrow move, Mod+F fullscreen, Mod+Ctrl+F maximize,
      # Mod+R cycle width, Mod+Escape quit, Mod+1-9 workspaces.
      # Everything in [keybinds] below is NOT built-in and must be declared.
      # Scratchpad uses Mod+S/Shift+S (Hyprland muscle memory) instead of
      # the example's Mod+Space/Shift+Space, which are taken by launcher/kitty.
      # =====================================================================
      programs.umbriel = {
        enable = true;

        settings = {
          general.autostart = [ "noctalia" ];

          # [colors]/[colors.border] come from Noctalia's native umbriel
          # theming now, not matugen (see modules/shells/noctalia/
          # default.nix's noctaliaEnableUmbrielTemplate activation). Noctalia
          # writes ~/.config/umbriel/noctalia.toml directly — that write
          # isn't blocked by our config.toml being a Nix-managed symlink
          # (same as kitty: its themes/noctalia.conf writes fine, only
          # injecting the include *into* kitty.conf itself is blocked).
          # Declaring the include ourselves here sidesteps needing Umbriel's
          # config.toml to be writable at all — Noctalia's own apply.sh
          # would have added this exact line if it could reach the file.
          include.files = [ "noctalia.toml" ];

          keybinds = {
            # ── Core apps ──────────────────────────────────────────────────
            "Mod+Return"       = "spawn:kitty";
            "Mod+Shift+Return" = "spawn:kitty --class floating-term";
            "Mod"              = "spawn:noctalia msg panel-toggle launcher";
            "Mod+E"            = "spawn:nautilus";

            # ── Window management ───────────────────────────────────────────
            "Mod+Q"       = "window-close";
            "Mod+F"       = "window-toggle-fullscreen";
            "Mod+T"       = "window-toggle-floating";
            "Mod+Shift+T" = "window-focus-switch-floating";
            "Mod+P"       = "window-toggle-pinned";
            "Mod+M"       = "window-toggle-maximize-to-edges";

            # ── Focus navigation (arrow keys; Mod+H/J/K/L are built-in) ────
            "Mod+Left"  = "window-focus-left";
            "Mod+Down"  = "window-focus-down";
            "Mod+Up"    = "window-focus-up";
            "Mod+Right" = "window-focus-right";

            # ── Overview ────────────────────────────────────────────────────
            "Mod+O" = { action = "overview-toggle"; repeat = false; };

            # ── Scratchpad — Mod+S/Shift+S matches Hyprland muscle memory ──
            # (example default is Mod+Space/Shift+Space, but those are taken
            #  by launcher and kitty-float; scratchpad is per-output in Umbriel)
            "Mod+S"          = "scratchpad-toggle";
            "Mod+Shift+S"    = "window-move-to-scratchpad";
            "Mod+Ctrl+Space" = "window-restore-from-scratchpad";
            "Mod+Tab"        = "scratchpad-focus-next";

            # ── Screenshots — save+notify, edit only if you click the
            # notification (matches Hyprland's screenshot.sh behavior,
            # ported to scripts/screenshot.sh) ─────────────────────────────
            "Print"             = "spawn:~/.config/umbriel/scripts/screenshot.sh area save";
            "Mod+Print"         = "spawn:~/.config/umbriel/scripts/screenshot.sh fullscreen save";
            "Mod+Z"             = "spawn:~/.config/umbriel/scripts/screenshot.sh area save";
            "Mod+X"             = "spawn:~/.config/umbriel/scripts/screenshot.sh fullscreen save";
            "Shift+Print"       = "spawn:~/.config/umbriel/scripts/screenshot.sh area copy";
            "Mod+Shift+Print"   = "spawn:~/.config/umbriel/scripts/screenshot.sh fullscreen copy";

            # ── Media keys ──────────────────────────────────────────────────
            "XF86AudioRaiseVolume" = "spawn:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            "XF86AudioLowerVolume" = "spawn:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            "XF86AudioMute"        = "spawn:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "XF86AudioMicMute"     = "spawn:wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            "XF86AudioPlay"        = "spawn:playerctl play-pause";
            "XF86AudioNext"        = "spawn:playerctl next";
            "XF86AudioPrev"        = "spawn:playerctl previous";

            # ── Brightness (allow_when_locked = works on the lock screen) ───
            "XF86MonBrightnessUp"   = { action = "spawn:brightnessctl set +5%"; allow_when_locked = true; };
            "XF86MonBrightnessDown" = { action = "spawn:brightnessctl set 5%-"; allow_when_locked = true; };
          };
        };
      };

      home.file.".config/umbriel/scripts/screenshot.sh" = {
        source = ../../../dotfiles/umbriel/scripts/screenshot.sh;
        executable = true;
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
    hyprpicker  # freeze-overlay during area selection — protocol-based, not Hyprland-only

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
