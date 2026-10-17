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
    photocraft  = { version = "0.9.0"; hash = "sha256-kTAMFIWtcQg5YEsIVTHJDnesfr2yowJZMJrXSvz9uQ0="; description = "Image editor"; };
    pdfcraft    = { version = "0.8.0"; hash = "sha256-P0/V3dmYAqPTSUdMYc89q9H7cZjqDfANJMwxBRa9HCo="; description = "PDF workbench"; };
    lightcraft  = { version = "0.8.0"; hash = "sha256-n+Dsxpt/Hzo1ocYwQps8Uv20QZuiCLVXm0UBuTj1GNE="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.12.0"; hash = "sha256-Z1DbEJ06JTxRyCl1r2UPQjhLonp2j3JSlDHt+1hQgmk="; description = "Vector illustration"; };
    filmcraft   = { version = "0.8.0"; hash = "sha256-sWaHeQWuihtVBQZtbd5g184Fgxz7MJus1deXD0uwF+E="; description = "Video editor"; };
    effectcraft = { version = "0.10.0"; hash = "sha256-dvv8CprTQ5lwGhjv6xwXhVfQHQoPS0A1FPLaxdiHVy4="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.8.0"; hash = "sha256-lqg1/Ynr9pcLfeyTZS4bLwgRI6aceOGZmMpshMoyLXc="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.7.0"; hash = "sha256-YwCfiOPbrqcKwTePq8hVWuFHddMoKRdcXaJVGr4Dky8="; description = "Word processor"; };
    gridcraft   = { version = "0.7.0"; hash = "sha256-wBvC3EKVVW9TgQ3+1KhaP1g4hVLBV6ED4QYmwGmznhw="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.7.0"; hash = "sha256-Mwovsu+IkNre2RCE5b/SnfpBHjOisnwBrDueUg/5jZ8="; description = "Presentations"; };
    soundcraft  = { version = "0.7.0"; hash = "sha256-jXr75f5DPLM4t8zuCCAoXWzhv8jABtVRyohAwnqRGrI="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.7.0"; hash = "sha256-z41KqG0EbzTrdwrmzS3z7uF9HzsSklfxVYVDBGyVXMA="; description = "CAD and drafting"; };
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
