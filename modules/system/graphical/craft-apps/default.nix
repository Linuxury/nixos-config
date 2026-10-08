# ===========================================================================
# modules/system/graphical/craft-apps/default.nix — storytold Craft apps
#
# PhotoCraft, PdfCraft, LightCraft, VectorCraft, FilmCraft, EffectCraft,
# DesignCraft (https://getartcraft.com/apps). Not in nixpkgs yet; packaged
# from upstream's prebuilt release tarballs in pkgs/craft-apps/package.nix
# (versions + hashes live there).
#
# Overlay is scoped here, so only hosts importing this module fetch them.
# ===========================================================================

{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      craft-apps = prev.callPackage ../../../../pkgs/craft-apps/package.nix {};
    })
  ];

  environment.systemPackages = builtins.attrValues pkgs.craft-apps;
}
