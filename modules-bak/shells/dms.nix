# ===========================================================================
# modules/shells/dms.nix — DankMaterialShell (DMS)
#
# Full Quickshell-based shell layer: bar, launcher, notifications, OSD,
# sidebar, dynamic matugen theming, wallpaper management, and dms-greeter
# login screen.
#
# Compositor-agnostic: DMS targets Hyprland by default but works on any
# wlr-layer-shell compositor. Set shell.dms.compositor = "niri" (etc.)
# to use it on another compositor.
#
# To enable:
#   shell.dms.enable = true;
#
# To switch away:
#   shell.dms.enable = false;
#   shell.wayle.enable = true;  # (or noctalia)
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
  # Import the NixOS-level greetd module that DMS provides.
  # Safe to import unconditionally — greetd only activates when
  # programs.dank-material-shell.greeter.enable = true (set below).
  imports = [ inputs.dms.nixosModules.greeter ];

  options.shell.dms = {
    enable = lib.mkEnableOption "DankMaterialShell shell layer";

    compositor = lib.mkOption {
      type        = lib.types.str;
      default     = "hyprland";
      description = ''
        Compositor name passed to dms-greeter.
        Common values: "hyprland", "niri", "sway".
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # =========================================================================
    # Login screen — dms-greeter (greetd backend)
    # =========================================================================
    programs.dank-material-shell.greeter = {
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

    # Copy the primary user's DMS config into the greeter cache so the login
    # screen inherits the active wallpaper and matugen color theme.
    systemd.services.greetd.preStart = lib.mkBefore ''
      for f in \
        "${home}/.config/DankMaterialShell/settings.json" \
        "${home}/.local/state/DankMaterialShell/session.json" \
        "${home}/.cache/DankMaterialShell/dms-colors.json"; do
        [ -f "$f" ] && cp --dereference "$f" ${cacheDir}/
      done
    '';

    # GNOME Keyring unlock via greetd PAM (dms-greeter auth path).
    security.pam.services.greetd.enableGnomeKeyring = true;

    # =========================================================================
    # Home Manager — DMS shell layer + DankSearch launcher index
    # Injected into every user on this host via sharedModules.
    # =========================================================================
    home-manager.sharedModules = [

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

      # Write DMS-specific Hyprland source overrides into shell-active.conf.
      # hyprland.conf sources this file so DMS colors/cursor/outputs/keybinds
      # are applied. On non-Hyprland compositors this file is unused.
      ({ lib, ... }: {
        home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _target="$HOME/nixos-config/dotfiles/hypr/shell-active.conf"
          [ -d "$(dirname "$_target")" ] || exit 0
          printf '%s\n' \
            'source = ./dms/colors.conf' \
            'source = ./dms/cursor.conf' \
            'source = ./dms/outputs.conf' \
            'source = ./dms/binds.conf' \
            > "$_target"
        '';
      })

    ];
  };
}
