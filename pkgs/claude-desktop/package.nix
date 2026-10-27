{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-core,
  cups,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libcap_ng,
  libnotify,
  libpulseaudio,
  libseccomp,
  libsecret,
  libxkbcommon,
  nss,
  pipewire,
  systemd,
  wayland,
  xdg-utils,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbfile,
  libxrandr,
  libxtst,
}:
# Anthropic's official Claude Desktop Linux beta, straight from their apt repo
# (https://downloads.claude.ai/claude-desktop/apt/stable). No third-party
# repack: the .deb is unpacked as-is and patched for Nix store paths only.
#
# Manual bump: edit version + hash. Both come from Anthropic's apt index:
#   curl -s https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages \
#     | grep -E '^(Version|SHA256):' | tail -2   # then: nix hash convert --hash-algo sha256 --to sri <hex>
#
# ponytail: Cowork (agent VM) not wired — needs qemu/OVMF/virtiofsd paths
# patched inside app.asar + the kvm group. Add if Cowork is wanted.
stdenv.mkDerivation rec {
  pname = "claude-desktop";
  version = "3.6556.2";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
    hash = "sha256-D27R8oRcMEGbhUWoMgZ210ZKGfYl4F4CkZI4qml47LQ=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];

  buildInputs = [
    stdenv.cc.cc.lib alsa-lib at-spi2-core cups gtk3 libdrm libgbm libnotify
    libcap_ng libseccomp libsecret nss pipewire systemd
    libx11 libxcb libxcomposite libxdamage libxext libxfixes libxkbfile
    libxrandr libxtst
  ];

  # dlopen'd at runtime, invisible to autoPatchelf's link scan.
  runtimeDependencies = [ libGL libpulseaudio libsecret libxkbcommon systemd wayland ];

  unpackPhase = "dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/share
    cp -a usr/lib/claude-desktop $out/lib/
    cp -a usr/share/applications usr/share/icons $out/share/
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --set-default ELECTRON_OZONE_PLATFORM_HINT auto \
      --add-flags --password-store=gnome-libsecret  # Electron guesses the keyring from XDG_CURRENT_DESKTOP; "umbriel" → no keyring
    runHook postInstall
  '';

  meta = {
    description = "Official Claude Desktop (Linux beta)";
    homepage = "https://claude.ai";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
