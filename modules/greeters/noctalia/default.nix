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
#   - Default session (matches services.displayManager.defaultSession)
#   - Cursor theme (Adwaita, matches the SDDM greeter's fallback)
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
    package = inputs.noctalia-greeter.packages.${pkgs.system}.default;

    settings = {
      session.default = "hyprland-session";

      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
      };

      cursor = {
        theme = "Adwaita";
        size = 24;
      };
    };
  };
}
