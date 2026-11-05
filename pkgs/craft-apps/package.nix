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
    photocraft  = { version = "0.20.2"; hash = "sha256-CeAT1o2DE+sLHNbyRhL1tf0NmT//46fBLOzf5c0TGkY="; description = "Image editor"; };
    pdfcraft    = { version = "0.18.2"; hash = "sha256-MjutezczkgdkYeLK1dtjsi9HoDK6AFpsSjXzSD0F2uQ="; description = "PDF workbench"; };
    lightcraft  = { version = "0.18.1"; hash = "sha256-B4+OT+9sqIr6JXpwIoYwsU4hOAzqWAMfu1xaGUK0BvA="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.21.1"; hash = "sha256-ODu6BvvefLh8fhN5N61RappYVJHFqSfYYx7lS78dTpM="; description = "Vector illustration"; };
    filmcraft   = { version = "0.17.1"; hash = "sha256-OXrp/s5VmzeGO0sHavRqY7bkOHw194Fwnk760U/nHr4="; description = "Video editor"; };
    effectcraft = { version = "0.21.1"; hash = "sha256-7DmvpR+wosC1iowRAjJeI1UBb+dUVj0kB1+imz4cUxU="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.17.2"; hash = "sha256-uS6QZ9sRuN4bs0gjLAlV0yRpNm+jlS1d2WwYyhgKKM4="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.15.2"; hash = "sha256-Nm5U4jW0Yxd5wMeMB3eogN5REWPekTCreM5ZWD96C5o="; description = "Word processor"; };
    gridcraft   = { version = "0.16.1"; hash = "sha256-Qp4DNM3TDtdev/WUU6ZEEUw8t+M0eZGoGzIEHXX0H+Q="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.15.1"; hash = "sha256-4tRRKdSw9dKCIyRVtzs10twWpPWHv2mh24CTmwreeM0="; description = "Presentations"; };
    soundcraft  = { version = "0.17.1"; hash = "sha256-56wUC7n9aa3k3QJkOvjl1MFKXILNZwsgMOUmiP67PLQ="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.17.1"; hash = "sha256-3aFlovLubh70nHzAJXteA4LetUHY6uAhExdogvny7AA="; description = "CAD and drafting"; };
    figcraft    = { version = "0.15.1"; hash = "sha256-1Xde+tyLtnOgt0HM2iicHr7Kb7P4J4laQM1X/wnEdNE="; description = "Interface design and prototyping"; };
    texturecraft = { version = "0.3.2"; hash = "sha256-T4/rxK9ZPe4brLUSk6788QLXqJgTbTzMxE9a1MGbwNA="; description = "Procedural texture designer"; };
    materialcraft = { version = "0.1.2"; hash = "sha256-IreCw7QUeJPD2cWn5pZXePyNgLTM/dGrwgEqO6IG/k0="; description = "Material and shader authoring"; };
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
