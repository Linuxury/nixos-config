# ===========================================================================
# modules/greeters/noctalia/default.nix — noctalia-greeter (greetd)
#
# First-party login greeter for Noctalia v5. Runs under greetd with its own
# bundled wlroots compositor — no SDDM/Qt6 involved.
#
# Bundled automatically by shells/noctalia/default.nix — importing that
# shell module pulls this in too, no separate host import needed. Only
# import this directly if you want the greeter without the Noctalia shell.
#
# What this module owns:
#   - services.greetd + programs.noctalia-greeter (enabled via the upstream
#     NixOS module — see inputs.noctalia-greeter.nixosModules.default)
#   - Default session — "Hyprland (quiet)", the log-suppressed UWSM wrapper
#     from modules/compositors/hyprland/default.nix (hyprland-session-pkg).
#     noctalia-greeter's session.default matches by picker label, not
#     .desktop id, so this must be the exact Name= string in that .desktop
#     file. Plain "Hyprland" (skips UWSM) and "Hyprland (uwsm-managed)"
#     (UWSM without output suppression, flashes boot text on handoff) are
#     also in the picker — both come from programs.hyprland.enable itself
#     and can't be hidden, but the quiet wrapper is the one to actually use.
#   - Cursor theme (BreezeX-Light, matches the Hyprland/Noctalia session —
#     see modules/themes/gtk/default.nix). Not in nixpkgs; provided by the
#     breezex-cursors overlay (flake.nix). Installed system-wide below so the
#     greeter compositor can find it under /run/current-system/sw/share/icons
#     regardless of which compositor module is paired with this shell.
#
# What this module does NOT own:
#   - Wallpaper/palette sync — appearance.scheme = "Synced" below picks up
#     whatever Noctalia Shell last pushed via Settings -> Security ->
#     Noctalia Greeter -> "Sync Now". That's a manual action in the shell,
#     not something worth replicating declaratively (unlike hypr-sddm's
#     matugen-driven wallpaper copy, which exists because SDDM has no
#     native concept of "the shell's current theme").
# ===========================================================================

{ inputs, pkgs, ... }:

{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  programs.noctalia-greeter = {
    enable = true;
    package = inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;

    settings = {
      session.default = "Hyprland (quiet)";

      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
      };

      cursor = {
        theme = "BreezeX-Light";
        size = 24;
        path = "/run/current-system/sw/share/icons";
      };
    };
  };

  environment.systemPackages = [ pkgs.breezex-cursors ];
}
