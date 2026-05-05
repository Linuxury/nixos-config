{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "breeze-chameleon-dark-icons";
  version = "0-unstable-2026-05-05";

  src = fetchFromGitHub {
    owner = "L4ki";
    repo  = "Breeze-Chameleon-Icons";
    rev   = "39ca2a55ba5289a96b2e744cd3670e020fb7e217";
    hash  = "sha256-wHsSNJE4PzhAU+OZSLejUIaeWf5UTRkw62Y8mj2SEE0=";
  };

  dontBuild     = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons
    cp -r "Breeze Chameleon Dark" $out/share/icons/

    runHook postInstall
  '';

  meta = {
    description = "Breeze Chameleon Dark icon theme — adaptive folder colors for KDE Plasma";
    homepage    = "https://github.com/L4ki/Breeze-Chameleon-Icons";
    license     = lib.licenses.gpl3Only;
    platforms   = lib.platforms.all;
    maintainers = [];
  };
}
