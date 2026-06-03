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
}
