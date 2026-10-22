{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:
# storytold Craft apps (https://getartcraft.com/apps) — prebuilt Linux release tarballs.
#
# Returns an attrset of derivations (pkgs.craft-apps.photocraft, …).
# Each tarball is a plain FHS tree (bin/, share/{applications,icons,mime,metainfo}),
# so copying it to $out gives the menu entry, icons and file associations.
#
# nru bumps these on Ryzen5900x (_nru_update_craft_apps in dotfiles/zsh/zshrc).
# Manual bump: edit version + hash below. Hashes come from upstream's SHA256SUMS.txt:
#   curl -sL https://github.com/storytold/<app>/releases/download/v<ver>/SHA256SUMS.txt \
#     | grep linux-x86_64.tar.gz   # then: nix hash convert --hash-algo sha256 --to sri <hex>
#
# Drop an app from here once it lands in nixpkgs.
let
  apps = {
    photocraft  = { version = "0.12.0"; hash = "sha256-+yuDAjDjICoe4Y7CDj9tJQ0naxZdeIEeg+tqdXJfnOI="; description = "Image editor"; };
    pdfcraft    = { version = "0.12.0"; hash = "sha256-0JYPCi+vcVL0VB8SWJlWAW6AaujLEhUsqnMiij0u0Wo="; description = "PDF workbench"; };
    lightcraft  = { version = "0.12.0"; hash = "sha256-hcjlqoT2tJzPm6iw/d5bdtF2hEv1zwK7B6Ko8L2HR2U="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.15.0"; hash = "sha256-XIszHl2chme95w0eObvkzKyEjrPkOianRAi5tjJSUuc="; description = "Vector illustration"; };
    filmcraft   = { version = "0.11.0"; hash = "sha256-bt6pL2+lDKMKyc09t+IO28y+4Mr+lkotwUk9jZxG2LQ="; description = "Video editor"; };
    effectcraft = { version = "0.15.0"; hash = "sha256-bJCT7Dab8PIvpCRWIKhWmJxDK2CAKSy8F0XkiLK532c="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.12.0"; hash = "sha256-Dnu+NJZw+NXrF4+pvUob8cfFHWpU4bgCuNzbsq5o/h0="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.10.0"; hash = "sha256-ypnqNQugrqQQP8gCDK2Y8FHFjZ6fz2cMEZ2BAQjMRf8="; description = "Word processor"; };
    gridcraft   = { version = "0.11.1"; hash = "sha256-8sg+bCZEmmxFmD6QO/MsHUwwKyBC8mPq2ZUnESnHDoc="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.10.0"; hash = "sha256-VGYW6yMAzo77ILRKU+YKv+a5bXGsYGtFKjb9Icax/yg="; description = "Presentations"; };
    soundcraft  = { version = "0.12.1"; hash = "sha256-sKVr1rXSfeaxLjVFgMNivm9ZEl6lj1cwRMhPan2od4A="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.11.0"; hash = "sha256-f1Ubsol8NAmZLL28n4Lg2V/Y7blJPOlBRy83/wQM5Y0="; description = "CAD and drafting"; };
    figcraft    = { version = "0.10.0"; hash = "sha256-s+L/2rVNIDo/btGgAYuDJTAL0i2+1qAvCvZ1fz62ado="; description = "Interface design and prototyping"; };
  };

  mk = pname: app: stdenv.mkDerivation {
    inherit pname;
    inherit (app) version;

    src = fetchurl {
      url = "https://github.com/storytold/${pname}/releases/download/v${app.version}/${pname}-${app.version}-linux-x86_64.tar.gz";
      inherit (app) hash;
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib alsa-lib ];

    # dlopen'd at runtime, invisible to autoPatchelf's link scan. X11 libs: DesignCraft
    # forces winit's X11 backend (file drag-and-drop), so it runs under XWayland.
    runtimeDependencies = [ libGL libxkbcommon vulkan-loader wayland libx11 libxcursor libxi libxrandr ];

    installPhase = ''
      runHook preInstall
      cp -r . "$out"
      runHook postInstall
    '';

    meta = {
      description = "${app.description} (storytold Craft app)";
      homepage = "https://github.com/storytold/${pname}";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
      mainProgram = pname;
    };
  };
in
lib.mapAttrs mk apps
