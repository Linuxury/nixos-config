{ lib, stdenvNoCC, proton-wineland-src, tag }:
# Proton Wineland prebuilt for Steam's compatibility tools.
#
# This file never needs to be edited. The version is derived from the tag
# passed by the overlay. The URL and hash live in modules/gaming/default.nix —
# nru updates them automatically via _nru_update_proton_wineland.
stdenvNoCC.mkDerivation {
  pname = "proton-wineland";
  version = tag;

  src = proton-wineland-src;

  # Prebuilt binary — skip all NixOS fixup steps.
  # Proton Wineland ships bundled libraries and runs inside Steam's
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
      -e 's|"[^"]*" // Internal|"proton_wineland_latest" // Internal|' \
      -e 's|"display_name" "[^"]*"|"display_name" "Proton-Wineland (Latest)"|' \
      "$out/compatibilitytool.vdf"
  '';

  meta = with lib; {
    description = "Proton Wineland: CachyOS-based Proton with Wayland improvements";
    homepage    = "https://github.com/nanomatters/proton-salkim";
    platforms   = [ "x86_64-linux" ];
    license     = licenses.unfreeRedistributable;
  };
}
