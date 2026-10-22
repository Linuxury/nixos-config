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
    pdfcraft    = { version = "0.11.0"; hash = "sha256-Da1dSyH8j9EZLouFTTjcwlf65mga4X8Q8bP0HoRIj08="; description = "PDF workbench"; };
    lightcraft  = { version = "0.11.0"; hash = "sha256-otG+HFKruB9aBzZiSiDOkocYPgsJVQBYKfSp3aQUlro="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.14.0"; hash = "sha256-WzSgXxI8pMxhHozmmoMQba7Y6iiLr2Phq7maQss7SG0="; description = "Vector illustration"; };
    filmcraft   = { version = "0.10.0"; hash = "sha256-ldehr8ueICHTNxoBFwCvbOL/4a8OHP6ZxvuYs6oyD4A="; description = "Video editor"; };
    effectcraft = { version = "0.14.0"; hash = "sha256-f0ZOTO3NpBj4uEBjxbOnm99ZqKbApOIpv3qq8FKl2ac="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.11.0"; hash = "sha256-Egdvic5EWvXPlsAEhwGn1INz3MvVJN4Z/iMIYBtVTVg="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.9.0"; hash = "sha256-j1B4AulxsWr6G23FZTF+swiF/7Kuwul206HdqkfFKdQ="; description = "Word processor"; };
    gridcraft   = { version = "0.10.0"; hash = "sha256-t4ooYFzTRZT8Nd/BrTapJAVFcaE4JiX7dQb9cM37kZc="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.9.0"; hash = "sha256-UxtMjNQ0ynZ+8h2g1E4JlmSvXV2WiwOLyPkncX+PqPE="; description = "Presentations"; };
    soundcraft  = { version = "0.11.0"; hash = "sha256-P0sDaDEPEEAEObTaMEhip9RjIxz8UdYFfhFGliov+jU="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.10.0"; hash = "sha256-K/E6vkZFZVyXHUUjBMBvmAgYSazoajKJ/Jkb7FU5LRg="; description = "CAD and drafting"; };
    figcraft    = { version = "0.9.0"; hash = "sha256-Z/eGyBbCVVmLwSChUKxXy1qPJGk10p/otNKvoI+IMww="; description = "Interface design and prototyping"; };
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
