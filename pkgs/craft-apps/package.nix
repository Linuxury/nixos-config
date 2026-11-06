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
    photocraft  = { version = "0.21.0"; hash = "sha256-MRXlbMZG2601QeObYyO4okMY/uYZTXhN320GX3tdLTc="; description = "Image editor"; };
    pdfcraft    = { version = "0.19.0"; hash = "sha256-NleqQP4UbUr0D6sFB8l/buLGzlupk4VnGUQ5vjM1uos="; description = "PDF workbench"; };
    lightcraft  = { version = "0.19.0"; hash = "sha256-lIXWS9vpjG2vutDqeqwPpJQw0KAIuaZrpD3+d7dVUok="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.22.0"; hash = "sha256-boEqksrsTboj/XRzT6IKMniG7yBCe1Xy+If+kzSgkz8="; description = "Vector illustration"; };
    filmcraft   = { version = "0.18.0"; hash = "sha256-AXnwWyDbhVv9Pe+RNs5g3uWfItLcv88j5KYlbgwVOwU="; description = "Video editor"; };
    effectcraft = { version = "0.22.0"; hash = "sha256-X+mwrldGrCm2H33qEL1ntx6ZbB4BiIJMT4GpZiPDvuk="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.18.0"; hash = "sha256-U5h8tmvn3pOFTtVwAEJ/vhwHKgQnvIy69QH/NnLVQyw="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.16.0"; hash = "sha256-MluX8Vu/UyYooxdqnBcUinF18+Txm5MT3jI6tRNgl1I="; description = "Word processor"; };
    gridcraft   = { version = "0.17.0"; hash = "sha256-FOk3RVW8bS2cW8QbsxFQvGoctrToPVq0Fj/V12EbBhg="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.16.0"; hash = "sha256-7tVysvYjldD1z+JGpygYllHpXk7N9MPgrYe3ejgx4IY="; description = "Presentations"; };
    soundcraft  = { version = "0.18.0"; hash = "sha256-M40f5yuWkqXZn/Q1UD31jIU/W5bC6VsoIdiD8x+LWmY="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.18.0"; hash = "sha256-DVtSKvz6IMfliIfCCS+1rVMi65DB2pgGHmG346zRvtU="; description = "CAD and drafting"; };
    figcraft    = { version = "0.16.0"; hash = "sha256-1ef5n0nTpwPX9SQYVNx1b7PVX8lNDJXSlw24SjM5H1o="; description = "Interface design and prototyping"; };
    texturecraft = { version = "0.4.0"; hash = "sha256-7YR2nrutIjFma9AA386KN5HysQd2b11WilVF1d4IRM8="; description = "Procedural texture designer"; };
    materialcraft = { version = "0.2.0"; hash = "sha256-PHtsGkdV4gTObg6mgT8WIuscNsFaRdU7o3InNXgLJvY="; description = "Material and shader authoring"; };
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
