# ===========================================================================
# modules/system/graphical/craft-apps/default.nix — storytold Craft apps
#
# PhotoCraft, PdfCraft, LightCraft, VectorCraft, FilmCraft, EffectCraft,
# DesignCraft, WordCraft, GridCraft, DeckCraft, SoundCraft, CADCraft
# (https://getartcraft.com/apps). Not in nixpkgs yet; packaged
# from upstream's prebuilt release tarballs in pkgs/craft-apps/package.nix
# (versions + hashes live there).
#
# Overlay is scoped here, so only hosts importing this module fetch them.
# ===========================================================================

{ lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      craft-apps = prev.callPackage ../../../../pkgs/craft-apps/package.nix {};
    })
  ];

  # filter: callPackage adds override/overrideDerivation functions to the attrset.
  environment.systemPackages = builtins.filter lib.isDerivation (builtins.attrValues pkgs.craft-apps);
}
