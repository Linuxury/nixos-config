# ===========================================================================
# modules/users/wallpapers/default.nix — writable ~/Pictures/Wallpapers
#
# A real folder in the user's home, so wallpapers can be added, replaced or
# deleted freely. It is filled from the Assets input (Wallpapers/<wallpaperDir>)
# by copying the files that are not there yet:
#   - files the user added are never touched
#   - files the user replaced or edited are never overwritten
#   - a repo wallpaper the user deleted comes back at the next rebuild
# New wallpapers pushed to the Assets repo therefore reach every machine with
# the next "nix flake update assets" + rebuild (nru does both).
#
# Imported by the three Home Manager user configs. wallpaperDir comes from
# extraSpecialArgs in flake.nix ("4k", "3440x1440" or "PikaOS").
# ===========================================================================

{ pkgs, lib, inputs, wallpaperDir, ... }:

{
  # After linkGeneration: it removes the old Home Manager symlink (a link into
  # the repo or the store) first, so what is left to create is a plain folder.
  home.activation.wallpapers = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    _dir="$HOME/Pictures/Wallpapers"
    [ -L "$_dir" ] && rm -f "$_dir"
    mkdir -p "$_dir"
    # --update=none: never overwrite. --no-preserve=mode: store files are
    # read-only, the copies must be writable. --reflink=auto: free on btrfs.
    ${pkgs.coreutils}/bin/cp -r --update=none --no-preserve=mode --reflink=auto \
      "${inputs.assets}/Wallpapers/${wallpaperDir}/." "$_dir/"
  '';
}
