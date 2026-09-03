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
#   - Default session — "Umbriel" (Name= from Umbriel's own session .desktop
#     entry, registered automatically by modules/compositors/umbriel).
#     session.default matches by picker label, not id. This module is shared
#     across every host that imports shells/noctalia — currently only
#     Ryzen5900x — so if a second Noctalia-shell host later runs a different
#     compositor, this default needs to become per-host instead of hardcoded
#     here. Not worth solving until there's a second such host.
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
      session.default = "Umbriel";

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
