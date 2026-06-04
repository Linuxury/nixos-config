# ===========================================================================
# modules/shells/dms/default.nix — DankMaterialShell (DMS)
#
# Full Quickshell-based shell layer: bar, launcher, notifications, OSD,
# sidebar, dynamic matugen theming, wallpaper management, and dms-greeter
# login screen.
#
# Importing this module activates DMS. No enable flag needed.
# DMS bundles its own greeter — do not add a separate greeter module.
#
# To switch shell: remove this import, add shells/wayle or shells/noctalia.
#
# Compositor: defaults to "hyprland". Override for other compositors:
#   shell.dms.compositor = "niri";
# ===========================================================================

{ config, lib, inputs, pkgs, ... }:

let
  cfg = config.shell.dms;

  # Resolve the primary normal user's home directory for the greetd preStart
  # color-sync script. Hyprland hosts have exactly one normal user.
  normalUsers  = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
  primaryUser  = lib.head (lib.attrNames normalUsers);
  home         = config.users.users.${primaryUser}.home;
  cacheDir     = "/var/lib/dms-greeter";
in

{
  imports = [ inputs.dms.nixosModules.greeter ];

  options.shell.dms.compositor = lib.mkOption {
    type        = lib.types.str;
    default     = "hyprland";
    description = ''
      Compositor name passed to dms-greeter.
      Common values: "hyprland", "niri", "sway".
    '';
  };

  # =========================================================================
  # Login screen — dms-greeter (greetd backend)
  # =========================================================================
  config.programs.dank-material-shell.greeter = {
    enable          = true;
    compositor.name = cfg.compositor;
    # Provide a full base config so the greeter's compositor picks up the
    # cursor theme. Without this, DMS generates a minimal config with no
    # cursor env, so the login screen defaults to the system cursor.
    compositor.customConfig = ''
      env = DMS_RUN_GREETER,1
      env = XCURSOR_THEME,BreezeX-Light
      env = XCURSOR_SIZE,24
      env = HYPRCURSOR_THEME,BreezeX-Light
      env = HYPRCURSOR_SIZE,24

      misc {
          disable_hyprland_logo = true
      }
    '';
  };

  config.systemd.services.greetd.preStart = lib.mkBefore ''
    for f in \
      "${home}/.config/DankMaterialShell/settings.json" \
      "${home}/.local/state/DankMaterialShell/session.json" \
      "${home}/.cache/DankMaterialShell/dms-colors.json"; do
      [ -f "$f" ] && cp --dereference "$f" ${cacheDir}/
    done
  '';

  # GNOME Keyring unlock via greetd PAM (dms-greeter auth path).
  config.security.pam.services.greetd.enableGnomeKeyring = true;

  # =========================================================================
  # Home Manager — DMS shell layer + DankSearch launcher index
  # Injected into every user on this host via sharedModules.
  # =========================================================================
  config.home-manager.sharedModules = [

    # DankMaterialShell — bar, launcher, notifications, OSD, sidebar,
    # dynamic theming, wallpaper management
    inputs.dms.homeModules.dank-material-shell
    {
      programs.dank-material-shell = {
        enable               = true;
        systemd.enable       = true;       # Auto-start with graphical session
        enableDynamicTheming = true;       # Matugen wallpaper-based colors
      };
    }

    # DankSearch — indexed filesystem search for the DMS launcher
    inputs.danksearch.homeModules.default
    { programs.dsearch.enable = true; }

    # Write DMS-specific Hyprland config overrides into shell-active.lua.
    # hyprland.lua dofile()s this file so DMS colors/cursor/outputs/keybinds
    # are applied. On non-Hyprland compositors this file is unused.
    ({ lib, ... }: {
      home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-active.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        printf '%s\n' \
          'require("dms.colors")' \
          'require("dms.cursor")' \
          'require("dms.outputs")' \
          'require("dms.binds")' \
          > "$_target"
      '';
    })

    # Clear shell-autostart.lua — DMS self-starts via its HM systemd module
    # (programs.dank-material-shell.systemd.enable = true), no exec-once needed.
    ({ lib, ... }: {
      home.activation.shellAutostartConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-autostart.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        : > "$_target"
      '';
    })

  ];
}
