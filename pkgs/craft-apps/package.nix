{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libGL,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:
# storytold Craft apps (https://getartcraft.com/apps) — prebuilt Linux release tarballs.
#
# Returns an attrset of 7 derivations (pkgs.craft-apps.photocraft, …).
# Each tarball is a plain FHS tree (bin/, share/{applications,icons,mime,metainfo}),
# so copying it to $out gives the menu entry, icons and file associations.
#
# Bumping: edit version + hash below. Hashes come from upstream's SHA256SUMS.txt:
#   curl -sL https://github.com/storytold/<app>/releases/download/v<ver>/SHA256SUMS.txt \
#     | grep linux-x86_64.tar.gz   # then: nix hash convert --hash-algo sha256 --to sri <hex>
#
# Drop an app from here once it lands in nixpkgs.
let
  apps = {
    photocraft  = { version = "0.5.0"; hash = "sha256-4EQQGy2lUiiW4dgza4EIfL7L9reLdoUxX1jdTz36TOA="; description = "Image editor"; };
    pdfcraft    = { version = "0.4.0"; hash = "sha256-SHmzzbTRJhlFrwOxxfAPPoaNBehOd5EZYMrFBaoWwds="; description = "PDF workbench"; };
    lightcraft  = { version = "0.4.0"; hash = "sha256-wsdXgLzwWKIcSjEc5X20flnwrC9t1wRYM3aa4QA7VyM="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.7.0"; hash = "sha256-1rDuV+G9vTd7RMhSToVprStN/0a3kvwQsO2/jXQpKs0="; description = "Vector illustration"; };
    filmcraft   = { version = "0.4.0"; hash = "sha256-hBeQ/2ZJ8NSdqkqK3hyxjZSOXKQ9AHcQRmY+BsjYzoM="; description = "Video editor"; };
    effectcraft = { version = "0.6.0"; hash = "sha256-cYEHGZAzeM2rMqH+Mo8jyHTTjNPYM6uxnGJj3SutIYw="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.4.0"; hash = "sha256-TAtowNxiCB5FW/jWDdVPAi/xYkNZ1eENBsorGNc9S7M="; description = "Page layout and publishing"; };
  };

  mk = pname: app: stdenv.mkDerivation {
    inherit pname;
    inherit (app) version;

    src = fetchurl {
      url = "https://github.com/storytold/${pname}/releases/download/v${app.version}/${pname}-${app.version}-linux-x86_64.tar.gz";
      inherit (app) hash;
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];

    # dlopen'd at runtime, invisible to autoPatchelf's link scan.
    runtimeDependencies = [ libGL libxkbcommon vulkan-loader wayland ];

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
