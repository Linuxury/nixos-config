{ lib, stdenvNoCC, proton-ge-src }:
# GE-Proton prebuilt for Steam's compatibility tools.
#
# This file never needs to be edited. The version is read directly from the
# tarball source, and the hash lives in flake.lock. nru handles URL updates
# in flake.nix automatically via _nru_update_proton_ge.
stdenvNoCC.mkDerivation rec {
  pname = "proton-ge-custom";
  # Read from the version file shipped inside the tarball: "1782266460 GE-Proton11-1"
  version = lib.last (lib.splitString " " (lib.trim (builtins.readFile "${proton-ge-src}/version")));

  src = proton-ge-src;

  # Prebuilt binary — skip all NixOS fixup steps.
  # GE-Proton ships bundled libraries and runs inside Steam's
  # pressure-vessel container; patchelf/strip would break it.
  dontBuild   = true;
  dontStrip   = true;
  dontFixup   = true;

  installPhase = ''
    cp -r . "$out"
  '';

  meta = with lib; {
    description = "GloriousEggroll's custom Proton build for Steam games";
    homepage    = "https://github.com/GloriousEggroll/proton-ge-custom";
    platforms   = [ "x86_64-linux" ];
    license     = licenses.unfreeRedistributable;
  };
}
