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
    photocraft  = { version = "0.20.1"; hash = "sha256-OYeH1Y/kaRnpnJ9W41VFVJ7wqqsAf4aakr7/fZ/lIjQ="; description = "Image editor"; };
    pdfcraft    = { version = "0.18.0"; hash = "sha256-yzZlzEXMeqa6AchouffGncTYAL71LUHP/qi/UDfE620="; description = "PDF workbench"; };
    lightcraft  = { version = "0.18.0"; hash = "sha256-8tyqKH1RD5ElJz2dFgiecTlDrvAFvQPZhI2VrFXYdQ8="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.21.0"; hash = "sha256-L/0A+zSTGOfpLpevN3z/2BjxcmRRt/IYnpLyJn6zTCE="; description = "Vector illustration"; };
    filmcraft   = { version = "0.17.0"; hash = "sha256-3z+KsjSBoo7vt8n9jTiZ+9lLsUPhlwaLRhP+BQKXv78="; description = "Video editor"; };
    effectcraft = { version = "0.21.0"; hash = "sha256-A/vJmKl5D6lJuQMzWXQM5mENt9GUJvDzgC9T6nDLgk0="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.17.0"; hash = "sha256-u2+c7EBGVTUCZumO4Q2bWhVFB+2ZitevR7JTNa+tGHI="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.15.0"; hash = "sha256-uqzxgVgSSrw9RdxEhb/Hel1xf4CsULgGk7ZQHCZpjl0="; description = "Word processor"; };
    gridcraft   = { version = "0.16.0"; hash = "sha256-TFwiMYa9HpT+2f7a88v3eprJbdRaMr82RI/AIwZvE98="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.15.0"; hash = "sha256-TjmoBFLELsLgASJYbwiKmrJ1AySa5nz0vbE5ENSjruQ="; description = "Presentations"; };
    soundcraft  = { version = "0.17.0"; hash = "sha256-MJv+y7METBbwogDWS1izQYNAifp4IR9yKvtQ6wVWbXE="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.17.0"; hash = "sha256-iZlrF2T/FWloV+CJTWC4RWkFEFGBj2SA6bf4I8dqRuQ="; description = "CAD and drafting"; };
    figcraft    = { version = "0.15.0"; hash = "sha256-Hl6OC5tKGBHzHOggSpvFPIUfIItv5F4ChzAvcLxqCNY="; description = "Interface design and prototyping"; };
    texturecraft = { version = "0.3.0"; hash = "sha256-xVN9KRCvjdeUEMf2r82cKGX3KjJSFUwuEqYTrMYLxj0="; description = "Procedural texture designer"; };
    materialcraft = { version = "0.1.0"; hash = "sha256-Z9BR7rJHcCGzpO18Zrj8tjErytvK9EydZDqzeeZ0AJE="; description = "Material and shader authoring"; };
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
