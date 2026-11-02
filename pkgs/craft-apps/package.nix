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
    photocraft  = { version = "0.19.0"; hash = "sha256-EjOFsXMKzhjxK8D0lGBuakzT9KuJH5MDbNTnG4rqcPc="; description = "Image editor"; };
    pdfcraft    = { version = "0.17.0"; hash = "sha256-+YFKegr3e5Ba26HDB5yu3uU3WGeXBDz1r5UDkU9qvsU="; description = "PDF workbench"; };
    lightcraft  = { version = "0.17.0"; hash = "sha256-0Yf1oVktSGYiDE0SfW5aPaT/p8lmzIffj0nnNcB88sE="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.20.0"; hash = "sha256-042D2eWf3PehAEFOIrMJQJT+T+LdQ6EF8EKXgBJhDoY="; description = "Vector illustration"; };
    filmcraft   = { version = "0.16.0"; hash = "sha256-WIOQ7uXX4WNPBXlMT4d93ylJTZz3RAURHWfBbL4hWuk="; description = "Video editor"; };
    effectcraft = { version = "0.20.0"; hash = "sha256-JXMQCgos4HppJXvaf6an1SUtO00y3+86H20slby42iM="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.16.0"; hash = "sha256-pIb8Q83I8kXtr3N8uxyaMoYO4YqNyhuv4IERAU4vFXY="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.14.0"; hash = "sha256-MBDaPTUtlSVuyaF6A5ZigKHUG6CdDr5WmvIwkti2SYc="; description = "Word processor"; };
    gridcraft   = { version = "0.15.0"; hash = "sha256-aBD4znOUtafN+vOYOCV7Y4Tc65+DJQJNR124le5Z2qo="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.14.1"; hash = "sha256-6Gx/oOy1XxpVPuQluT3P3IBrezeY8nK0Hx0f90rFwSo="; description = "Presentations"; };
    soundcraft  = { version = "0.16.0"; hash = "sha256-Jcawy4kkGY8i46bydx19zJ4EGjJEpL5EXL3p0A59wZ4="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.16.0"; hash = "sha256-FJggs9Dh5ymiJW40RSO5gFhx057jnJ4IX1B3B/c8y9Q="; description = "CAD and drafting"; };
    figcraft    = { version = "0.14.0"; hash = "sha256-DqSJzimSOK+WEGlAzdtCCRw+uhCcBf34Q7Tn+OuXCCk="; description = "Interface design and prototyping"; };
    texturecraft = { version = "0.2.0"; hash = "sha256-mRkGixPYgNUS1qmVQzRGyfzLPgtEf9zix3FuE5PXz7I="; description = "Procedural texture designer"; };
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
