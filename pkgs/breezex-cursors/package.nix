{ lib, stdenvNoCC, fetchzip }:

stdenvNoCC.mkDerivation {
  pname   = "breezex-cursor-theme";
  version = "2.0.1";

  src = fetchzip {
    url       = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX.tar.xz";
    sha256    = "10fbvbls52cgp5kshlcxbh3nqarh2mwhpj0w5kkk4hrl3sdc1bcj";
    stripRoot = false; # archive has multiple top-level dirs (BreezeX, BreezeX-Black, …)
  };

  dontBuild     = true;
  dontConfigure = true;

  installPhase = ''
    mkdir -p $out/share/icons
    cp -r . $out/share/icons/
  '';

  meta = {
    description = "BreezeX cursor theme — refined KDE Breeze cursor with larger sizes";
    homepage    = "https://github.com/ful1e5/BreezeX_Cursor";
    license     = lib.licenses.gpl3Only;
    platforms   = lib.platforms.all;
  };
}
