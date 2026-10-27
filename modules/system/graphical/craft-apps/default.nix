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
# ~/.config/Claude/claude_desktop_config.json. Each app reads only its type
# folder (~/Pictures, ~/Documents, ~/Videos, ~/Music) and writes only to that
# folder's Craft/ subfolder: new files land there and originals can't be
# overwritten. The CLIs take one read and one write root each (repeats are
# refused). LightCraft/FilmCraft/GridCraft/CADCraft have no root flags
# (unconfined); their dir only decides which Craft/ folder gets created.
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

  # Type folder under ~ + args after `<app>-cli`. "roots" = read <dir>,
  # write <dir>/Craft.
  mcp = {
    photocraft  = { dir = "Pictures";  args = [ "mcp" "roots" ]; };
    lightcraft  = { dir = "Pictures";  args = [ "mcp" "--compact" ]; };           # 393 tools → 17
    vectorcraft = { dir = "Pictures";  args = [ "mcp" "--headless" "roots" ]; };  # default tries the GUI on :7979 first
    figcraft    = { dir = "Pictures";  args = [ "mcp" "roots" ]; };
    wordcraft   = { dir = "Documents"; args = [ "mcp" "roots" ]; };
    pdfcraft    = { dir = "Documents"; args = [ "mcp" "--compact" "roots" ]; };   # 179 tools → 17
    deckcraft   = { dir = "Documents"; args = [ "mcp" "roots" ]; };
    designcraft = { dir = "Documents"; args = [ "mcp" "roots" ]; };
    gridcraft   = { dir = "Documents"; args = [ "mcp" ]; };
    cadcraft    = { dir = "Documents"; args = [ "mcp" ]; };
    effectcraft = { dir = "Videos";    args = [ "mcp" "roots" ]; };
    filmcraft   = { dir = "Videos";    args = [ "mcp" ]; };
    soundcraft  = { dir = "Music";     args = [ "mcp" "roots" ]; };
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
        craftDir = app: "${home}/${mcp.${app.pname}.dir}/Craft";
        servers = lib.listToAttrs (map (app: let m = mcp.${app.pname}; in lib.nameValuePair app.pname {
          command = "${app}/bin/${app.pname}-cli";
          args = lib.concatMap (a: if a == "roots"
            then [ "--automation-read-root" "${home}/${m.dir}" "--automation-write-root" (craftDir app) ]
            else [ a ]) m.args;
        }) installed);
        craftDirs = lib.escapeShellArgs (lib.unique (map craftDir installed));
        serversJson = pkgs.writeText "craft-mcp-servers.json" (builtins.toJSON servers);
        # Every Craft server name, installed or not, so the merge removes
        # exactly these keys and never a hand-added server like "minecraft".
        craftNames = lib.escapeShellArg (builtins.toJSON (lib.attrNames mcp));
      in {
        # The app rewrites this file itself, so merge instead of symlinking.
        # Craft keys are replaced wholesale: a dropped suite drops its servers.
        # Writes go through `run` (no-op under --dry-run) and land via
        # tmp + mv, so a failed or interrupted switch never truncates it.
        home.activation.registerCraftMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${craftDirs} "${home}/.config/Claude"
          _cfg="${home}/.config/Claude/claude_desktop_config.json"
          _cur=$(cat "$_cfg" 2>/dev/null || printf '{}')
          if _new=$(printf '%s' "$_cur" | ${lib.getExe pkgs.jq} \
              --slurpfile s ${serversJson} --argjson names ${craftNames} \
              '.mcpServers = ((.mcpServers // {} | with_entries(select(.key as $k | $names | index($k) | not))) + $s[0])'); then
            if [ "$_new" != "$_cur" ]; then
              printf '%s\n' "$_new" | run tee "$_cfg.hm-tmp" > /dev/null
              run mv "$_cfg.hm-tmp" "$_cfg"
            fi
          else
            warnEcho "registerCraftMcp: $_cfg is not valid JSON; left untouched"
          fi
          unset _cfg _cur _new
        '';
      })
    ];
  };
}
