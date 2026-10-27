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
#   design — PhotoCraft, LightCraft, VectorCraft, DesignCraft, FigCraft
#            (Photoshop/Lightroom/Illustrator/InDesign/Figma)
#   video  — FilmCraft, EffectCraft                      (Premiere/After Effects)
#   audio  — SoundCraft                                  (Audition)
#   cad    — CADCraft                                    (AutoCAD)
#
# Overlay is scoped here, so only hosts importing this module fetch them.
#
# Claude Desktop: on hosts that also import claude-desktop, each installed
# app's `<app>-cli mcp` (headless stdio MCP server) is merged into
# ~/.config/Claude/claude_desktop_config.json. Reads anywhere in ~, writes
# only to ~/Documents/Craft. FilmCraft/GridCraft/CADCraft have no root flags
# (unconfined); LightCraft only touches files it's given.
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  suites = with pkgs.craft-apps; {
    office = [ wordcraft gridcraft deckcraft pdfcraft ];
    design = [ photocraft lightcraft vectorcraft designcraft figcraft ];
    video  = [ filmcraft effectcraft ];
    audio  = [ soundcraft ];
    cad    = [ cadcraft ];
  };
  installed = lib.concatMap (s: suites.${s}) config.craftApps.suites;

  # Args after `<app>-cli`. "roots" = confined to the automation roots below.
  mcpArgs = {
    photocraft  = [ "mcp" "roots" ];
    pdfcraft    = [ "mcp" "--compact" "roots" ];   # 179 tools → 17
    lightcraft  = [ "mcp" "--compact" ];           # 393 tools → 17
    vectorcraft = [ "mcp" "--headless" "roots" ];  # default tries the GUI on :7979 first
    filmcraft   = [ "mcp" ];
    effectcraft = [ "mcp" "roots" ];
    designcraft = [ "mcp" "roots" ];
    wordcraft   = [ "mcp" "roots" ];
    gridcraft   = [ "mcp" ];
    deckcraft   = [ "mcp" "roots" ];
    soundcraft  = [ "mcp" "roots" ];
    cadcraft    = [ "mcp" ];
    figcraft    = [ "mcp" "roots" ];
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

    environment.systemPackages = installed;

    # The claude-desktop overlay is scoped to its module, so this is exactly
    # the hosts that have Claude Desktop.
    home-manager.sharedModules = lib.mkIf (pkgs ? claude-desktop) [
      ({ config, lib, pkgs, ... }: let
        home = config.home.homeDirectory;
        roots = [ "--automation-read-root" home "--automation-write-root" "${home}/Documents/Craft" ];
        servers = lib.listToAttrs (map (app: lib.nameValuePair app.pname {
          command = "${app}/bin/${app.pname}-cli";
          args = lib.concatMap (a: if a == "roots" then roots else [ a ]) mcpArgs.${app.pname};
        }) installed);
        serversJson = pkgs.writeText "craft-mcp-servers.json" (builtins.toJSON servers);
      in {
        # The app rewrites this file itself, so merge instead of symlinking.
        # Craft keys are replaced wholesale: a dropped suite drops its servers.
        home.activation.registerCraftMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "${home}/Documents/Craft" "${home}/.config/Claude"
          _cfg="${home}/.config/Claude/claude_desktop_config.json"
          [ -f "$_cfg" ] || printf '{}' > "$_cfg"
          _tmp=$(${lib.getExe pkgs.jq} --slurpfile s ${serversJson} \
            '.mcpServers = ((.mcpServers // {} | with_entries(select(.key | endswith("craft") | not))) + $s[0])' \
            "$_cfg") && printf '%s\n' "$_tmp" > "$_cfg"
          unset _cfg _tmp
        '';
      })
    ];
  };
}
