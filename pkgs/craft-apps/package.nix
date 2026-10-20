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
    photocraft  = { version = "0.10.0"; hash = "sha256-xdRVeF2cLq9pW/jmMnxNbSOjnduVamEU8MW2Qyb5hOE="; description = "Image editor"; };
    pdfcraft    = { version = "0.9.0"; hash = "sha256-/199o2oQiTQOP9umlrKGzDF6yPBwXMjETBxJ2cpMVOA="; description = "PDF workbench"; };
    lightcraft  = { version = "0.9.1"; hash = "sha256-f2KX06FZqjkbE6rASTl3MDBcwEqNvxKrD/YfhvVR96k="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.13.1"; hash = "sha256-NcD89tP56/9vM9JX/3Du9BQpbzfw2B8oTm+XDiD9ssg="; description = "Vector illustration"; };
    filmcraft   = { version = "0.9.0"; hash = "sha256-6meVPMdUv9gnLg5fqUBRjhYGiulva3Ki3OVm7WmmFjI="; description = "Video editor"; };
    effectcraft = { version = "0.11.1"; hash = "sha256-ucss5o3WZFjMFkQ35DE3bpTjjjPjtlKfqP1F+M+WiTQ="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.10.0"; hash = "sha256-SjcI+oeNr1GIqiumb9fNGGvzhpCmwVJG7IPYU+De65Q="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.8.0"; hash = "sha256-Ds4Hzz2RuSPf2A+QMQ4EmDveZvAnnGtg3c6JWW3eDd8="; description = "Word processor"; };
    gridcraft   = { version = "0.9.0"; hash = "sha256-gRSC8uS7ZvjDXVm3nlMuHQgS02K6wk5j/W3cCETWa8k="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.8.0"; hash = "sha256-InuMnN0sBreGaAf5lf5dLQZ1UjphII+bwmzydg/dy48="; description = "Presentations"; };
    soundcraft  = { version = "0.10.0"; hash = "sha256-RkGNVv782s0obmppb7Uj9X9UXV8UHEb8crpzc4trbHA="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.8.0"; hash = "sha256-3zwuZoQ58EEFZLH6nSGCe7Zj6z0BcDkCxB8CucUnYZM="; description = "CAD and drafting"; };
    figcraft    = { version = "0.8.0"; hash = "sha256-w1DcWufjDIWgY1epTP32BPKybzpOtje0Tw94v/fDSYU="; description = "Interface design and prototyping"; };
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
