{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "ant-dark-kde";
  version = "0-unstable-2026-04-28";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo  = "Ant";
    rev   = "79ddc06b40ad1e96c87d9270c71d7db3bfa0c3cd";
    hash  = "sha256-dAx05R9QWkDcuzJF/GUhK2R7hGjY7JvtTyXEDpE+p5E=";
  };

  dontBuild     = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    # Aurorae window decorations
    mkdir -p $out/share/aurorae/themes
    cp -r kde/Dark/aurorae/Ant-Dark $out/share/aurorae/themes/

    # Plasma desktop theme
    mkdir -p $out/share/plasma/desktoptheme
    cp -r kde/Dark/plasma/desktoptheme/Ant-Dark $out/share/plasma/desktoptheme/

    # Plasma look-and-feel (global theme)
    mkdir -p $out/share/plasma/look-and-feel
    cp -r kde/Dark/plasma/look-and-feel/Ant-Dark $out/share/plasma/look-and-feel/

    # Color scheme
    mkdir -p $out/share/color-schemes
    cp kde/Dark/color-schemes/Ant-Dark.colors $out/share/color-schemes/

    # Kvantum Qt application theme
    mkdir -p $out/share/Kvantum
    cp -r kde/Dark/kvantum/Ant-Dark $out/share/Kvantum/

    # Konsole terminal color scheme
    mkdir -p $out/share/konsole
    cp kde/Dark/konsole/Ant-Dark.colorscheme $out/share/konsole/

    runHook postInstall
  '';

  meta = {
    description = "Ant-Dark KDE theme — Aurorae, Plasma desktop theme, color scheme, and Kvantum style";
    homepage    = "https://github.com/EliverLara/Ant";
    license     = lib.licenses.gpl3Only;
    platforms   = lib.platforms.all;
    maintainers = [];
  };
}
