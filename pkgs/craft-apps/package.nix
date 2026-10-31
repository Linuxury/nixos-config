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
    photocraft  = { version = "0.18.0"; hash = "sha256-S4rI4RRqyal+e/3vFrJn1Tlqd4Cf1OIym4Pa14CGV08="; description = "Image editor"; };
    pdfcraft    = { version = "0.16.1"; hash = "sha256-uzbgcdEKFK9RISmaDu2NfF245cdYC2y+vsCFxB0b/go="; description = "PDF workbench"; };
    lightcraft  = { version = "0.16.0"; hash = "sha256-0i7fWsQBACkdjD2N3ovxyRyuIaC1bUypzAAm2zE5qSY="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.19.0"; hash = "sha256-rlN4iPSWkZqosxk+om8F/SWEvgDv+G2AoH4mRPEGHpI="; description = "Vector illustration"; };
    filmcraft   = { version = "0.15.0"; hash = "sha256-IrEGtMpilNmz6aSvQLQKZToYl0NzZIBQRqAd26pLIsE="; description = "Video editor"; };
    effectcraft = { version = "0.19.0"; hash = "sha256-fsk5Ha53X3zn5ykSaPexIzIowbreg87YhAMDU1yVGXA="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.15.2"; hash = "sha256-57eC90ZJd+/pNa1o48kIsJOfO2ZgcMiN8gRhmNxuiUQ="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.13.2"; hash = "sha256-bPT8wDCi1PuvM0+dbGDXPCof3uKmlRwGfl+hFf4Qc48="; description = "Word processor"; };
    gridcraft   = { version = "0.14.2"; hash = "sha256-nIFTt2MK373vgCGqm5guHvGHts8nzSIzKAz68LpqGEI="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.13.1"; hash = "sha256-cR7AlbWQ+8uqq8jFklqDUN6pjukxq3tE1Ir2iy5h9RQ="; description = "Presentations"; };
    soundcraft  = { version = "0.15.0"; hash = "sha256-Fu8j72LsIPX8xT4Eq6r/UnCV5QX1YItHqxtyscjp7SA="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.15.1"; hash = "sha256-0ETw+KdVxrab3GtFNh2rzDQsFOOxkZw59UBp/80cT4A="; description = "CAD and drafting"; };
    figcraft    = { version = "0.13.1"; hash = "sha256-hlzynHWnN82FnZP6SOnUqo3GAj8liqEn6IuX2If5DSc="; description = "Interface design and prototyping"; };
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
