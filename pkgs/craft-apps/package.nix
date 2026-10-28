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
    photocraft  = { version = "0.17.0"; hash = "sha256-Uln5xCjI7jR4w1UA7OmHE1Ycr8BQ5MnrNUpQUPNusrg="; description = "Image editor"; };
    pdfcraft    = { version = "0.15.0"; hash = "sha256-sWehjGCnsynwWlu/l+Mtxniq0/jVhm2OQ3j/JCc/gxM="; description = "PDF workbench"; };
    lightcraft  = { version = "0.15.0"; hash = "sha256-CxrN78CFurszS5rdKQ3RpptQ6W772tLsFdRL1tZL/T0="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.18.0"; hash = "sha256-dpSLUO943Ugqbs4G8QtwR5N7vAwF9c9rxD2IsH902CY="; description = "Vector illustration"; };
    filmcraft   = { version = "0.14.0"; hash = "sha256-0qohPMCKvSHgWrURp4zDjxV8ryImmS8/yKXgSWo/fn0="; description = "Video editor"; };
    effectcraft = { version = "0.18.0"; hash = "sha256-lNHYVpHVS6V/qG4Ehy+8xCbDPRvTZPH8l2sfYHNEiAs="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.14.0"; hash = "sha256-Jch751nTWoHKROH2Je1DBLFuWqtqA6EFG8pJioG/xUc="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.12.0"; hash = "sha256-zZq9DuehG5ha8cFXFlMzLJYHfl3MSLXhh7VcgvR1oz4="; description = "Word processor"; };
    gridcraft   = { version = "0.13.0"; hash = "sha256-IMbFbsH/1rvP/ubN7ljPa1yt0vSgSkNg3XzGTVOtl+U="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.12.0"; hash = "sha256-SkENPKpCPoc9Dcq1HJjgZYj1W9/PA+nB6RQJqGwI3j4="; description = "Presentations"; };
    soundcraft  = { version = "0.14.0"; hash = "sha256-L4NQP+2mqiyNS8EsRPVxQixDifxmSpK77QktK/HVAK0="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.14.0"; hash = "sha256-lQZ8hJ+CMFZIJJKZu4bmRbcwJ1qoxfGZZdgZkPg66ps="; description = "CAD and drafting"; };
    figcraft    = { version = "0.12.1"; hash = "sha256-AKKfTMOCgH2ED10+m1n0yIKTVnia+7lWoJZJGCleSd0="; description = "Interface design and prototyping"; };
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
