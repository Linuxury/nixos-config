{ lib, stdenvNoCC, proton-cachyos-src, tag }:
# Proton-CachyOS prebuilt for Steam's compatibility tools.
#
# This file never needs to be edited. The version is derived from the tag
# passed by the overlay. The URL and hash live in modules/gaming/default.nix —
# nru updates them automatically via _nru_update_proton_cachyos.
stdenvNoCC.mkDerivation {
  pname = "proton-cachyos";
  version = tag;

  src = proton-cachyos-src;

  # Prebuilt binary — skip all NixOS fixup steps.
  # Proton-CachyOS ships bundled libraries and runs inside Steam's
  # pressure-vessel container; patchelf/strip would break it.
  dontBuild   = true;
  dontStrip   = true;
  dontFixup   = true;

  installPhase = ''
    cp -r . "$out"

    # Patch compatibilitytool.vdf with stable names so Steam game assignments
    # survive version updates. The internal key varies per release; we detect
    # it generically via the "// Internal" marker rather than hardcoding it.
    chmod +w "$out/compatibilitytool.vdf"
    sed -i \
      -e 's|"[^"]*" // Internal|"proton_cachyos_latest" // Internal|' \
      -e 's|"display_name" "[^"]*"|"display_name" "Proton-CachyOS (Latest)"|' \
      "$out/compatibilitytool.vdf"
  '';

  meta = with lib; {
    description = "CachyOS's custom Proton build for Steam games";
    homepage    = "https://github.com/CachyOS/proton-cachyos";
    platforms   = [ "x86_64-linux" ];
    license     = licenses.unfreeRedistributable;
  };
}
