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
    photocraft  = { version = "0.15.1"; hash = "sha256-tiK+QDVVEwVvgVKv6JXQoFwbw8NEoCf3cqmhL6PRwiM="; description = "Image editor"; };
    pdfcraft    = { version = "0.13.0"; hash = "sha256-WYUZ6ivHfGbKmpBiQeH+Psz3RfUGJ84829W15nWkVtM="; description = "PDF workbench"; };
    lightcraft  = { version = "0.13.0"; hash = "sha256-hzx5XmQeqMNF4C5IlfbCZZAV5TFCD2g1LKNCGqm47c0="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.16.0"; hash = "sha256-ZR+sFyVSca0dvIuh6Ch9ufKOUpupoU3QOD7Kk6LMWqY="; description = "Vector illustration"; };
    filmcraft   = { version = "0.12.0"; hash = "sha256-3f8KLsDYnl6eZWRO1yS1t5lZYAsWAv1OpmU7WlS/iP0="; description = "Video editor"; };
    effectcraft = { version = "0.16.0"; hash = "sha256-kbQNqeGL5JFXRnqW23svv3wgtRgtjEFcWb7VFZG8HeA="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.12.0"; hash = "sha256-Dnu+NJZw+NXrF4+pvUob8cfFHWpU4bgCuNzbsq5o/h0="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.10.0"; hash = "sha256-ypnqNQugrqQQP8gCDK2Y8FHFjZ6fz2cMEZ2BAQjMRf8="; description = "Word processor"; };
    gridcraft   = { version = "0.11.1"; hash = "sha256-8sg+bCZEmmxFmD6QO/MsHUwwKyBC8mPq2ZUnESnHDoc="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.10.0"; hash = "sha256-VGYW6yMAzo77ILRKU+YKv+a5bXGsYGtFKjb9Icax/yg="; description = "Presentations"; };
    soundcraft  = { version = "0.12.1"; hash = "sha256-sKVr1rXSfeaxLjVFgMNivm9ZEl6lj1cwRMhPan2od4A="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.12.0"; hash = "sha256-auJ7nqvDYIyu81agD2m5/cy/HkCNYwi1YUtuayVjCN4="; description = "CAD and drafting"; };
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

    # Nothing is compiled here — untar a prebuilt tree, then autoPatchelf it.
    # Without this, a remote builder gets picked and the transfer dwarfs the
    # work: ~60-106 MB tarball up, ~127-195 MB output back, per app, times 13.
    # On a wifi host (ThinkPad) that turned a seconds-long unpack into minutes.
    preferLocalBuild = true;

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
