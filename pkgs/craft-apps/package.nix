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
    photocraft  = { version = "0.16.0"; hash = "sha256-fBfzYz6/favydiji0mN9kYx8KlsWO4uQNHp4rN32Ngg="; description = "Image editor"; };
    pdfcraft    = { version = "0.14.0"; hash = "sha256-qT9RHof2MDbKX1MAsaehijzSKFIF3qsVOUyqbug8bx8="; description = "PDF workbench"; };
    lightcraft  = { version = "0.14.0"; hash = "sha256-uCM7k3PW6ZsRgMHDn9yxPUnEQfgAkncIMfqxlcTE/aI="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.17.0"; hash = "sha256-ZsKJ0L01S3HkzXhxk+oEgeOhzSOfKhgGgRDqNoUvwCY="; description = "Vector illustration"; };
    filmcraft   = { version = "0.13.0"; hash = "sha256-QOnWhfs+0bCiHJwCIR8ahJngmkfFUSRM5+6A8lhNOps="; description = "Video editor"; };
    effectcraft = { version = "0.17.0"; hash = "sha256-zXrODXRzS3noUfGFN8FLKVO3/rXaJA9QBeaAVHahUpI="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.13.0"; hash = "sha256-UxTUa8Ugz1SDWi0SkzUb4f7RFiKOBVOTAZcp8E4PmcI="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.11.0"; hash = "sha256-A0wke/basXKi7fsHZ96QZRJbhXgmxpFffvObn0OVHVo="; description = "Word processor"; };
    gridcraft   = { version = "0.12.1"; hash = "sha256-HBdQ3W0mN2z4yK8itG3A7T2NXLsRXlVfD8fQz3qa6po="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.11.1"; hash = "sha256-e/V6EKT892c+y2abZODlRUdXgO8+Tua/YDrrAPVE5pw="; description = "Presentations"; };
    soundcraft  = { version = "0.13.1"; hash = "sha256-Ce5siEWTT+70u/TFwOLw/8o/yREm/XpqQGGx+DkHRW0="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.13.0"; hash = "sha256-04dVvrYYiXVr69k430kebuDeeMLzX9NRBaR5kJ/RypI="; description = "CAD and drafting"; };
    figcraft    = { version = "0.11.2"; hash = "sha256-adIdDTcXc4+dp50EvIbBUum4+RnmOVrpexy1azbN4rk="; description = "Interface design and prototyping"; };
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
