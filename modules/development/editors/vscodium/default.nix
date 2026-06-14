# ===========================================================================
# modules/development/editors/vscodium/default.nix — VSCodium (NixOS entry point)
#
# Injects the VSCodium Home Manager config (hm.nix) into linuxury's HM profile.
# Extensions, settings generation, and the NixOS Claude wrapper fix live in hm.nix.
#
# Import this module in the host config to activate VSCodium for linuxury.
# ===========================================================================

{ ... }:

{
  home-manager.users.linuxury.imports = [ ./hm.nix ];

  # Text editor MIME defaults — plain priority overrides Neovim's lib.mkDefault,
  # but yields to Zed's lib.mkForce if Zed is also installed on this host.
  home-manager.sharedModules = [{
    xdg.mimeApps.defaultApplications = {
      "text/plain"                = "codium.desktop";
      "application/json"          = "codium.desktop";
      "application/x-yaml"        = "codium.desktop";
      "application/toml"          = "codium.desktop";
      "application/x-shellscript" = "codium.desktop";
      "text/x-shellscript"        = "codium.desktop";
    };
  }];
}
