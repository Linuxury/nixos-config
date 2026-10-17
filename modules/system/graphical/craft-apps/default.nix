# ===========================================================================
# modules/system/graphical/craft-apps/default.nix — storytold Craft apps
#
# (https://getartcraft.com/apps). Not in nixpkgs yet; packaged
# from upstream's prebuilt release tarballs in pkgs/craft-apps/package.nix
# (versions + hashes live there).
#
# Grouped into suites mirroring Microsoft/Adobe. Hosts pick with:
#   craftApps.suites = [ "office" ];   # default: all suites
#
#   office — WordCraft, GridCraft, DeckCraft, PdfCraft   (Word/Excel/PowerPoint/Acrobat)
#   design — PhotoCraft, LightCraft, VectorCraft, DesignCraft
#            (Photoshop/Lightroom/Illustrator/InDesign)
#   video  — FilmCraft, EffectCraft                      (Premiere/After Effects)
#   audio  — SoundCraft                                  (Audition)
#   cad    — CADCraft                                    (AutoCAD)
#
# Overlay is scoped here, so only hosts importing this module fetch them.
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  suites = with pkgs.craft-apps; {
    office = [ wordcraft gridcraft deckcraft pdfcraft ];
    design = [ photocraft lightcraft vectorcraft designcraft ];
    video  = [ filmcraft effectcraft ];
    audio  = [ soundcraft ];
    cad    = [ cadcraft ];
  };
in
{
  options.craftApps.suites = lib.mkOption {
    type        = lib.types.listOf (lib.types.enum (lib.attrNames suites));
    default     = lib.attrNames suites;
    description = "Which Craft app suites to install.";
  };

  config = {
    nixpkgs.overlays = [
      (final: prev: {
        craft-apps = prev.callPackage ../../../../pkgs/craft-apps/package.nix {};
      })
    ];

    environment.systemPackages = lib.concatMap (s: suites.${s}) config.craftApps.suites;
  };
}
