{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  python3,
  # build-time libs (linked)
  fontconfig,
  glib,
  gdk-pixbuf,
  libglvnd,
  libxcb,
  libxkbcommon,
  wayland,
  vulkan-loader,
  libheif,
  mpv-unwrapped,
  poppler,
  # runtime tools Flea shells out to
  bat,
  bubblewrap,
  expect,
  jq,
  quickjs-ng,
  ripgrep,
  util-linux,
  wl-clipboard,
  xdg-utils,
  udisks,
  shared-mime-info,
}:
# Flea (https://github.com/thisisgm/flea) — keyboard-first GPUI file manager
# written for Omarchy. The `flea-gui` binary is a native GPUI window; the
# Quickshell front end (ui/, needs Omarchy's QML shell) is NOT installed here.
# Without Omarchy, `flea --default` / `omarchy update` hooks do nothing useful.
rustPlatform.buildRustPackage rec {
  pname = "flea";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "thisisgm";
    repo = "flea";
    rev = "v${version}";
    hash = "sha256-zzGFgcpA2D3AwGKjt8H1cz9mwi/i/iqBNB4xLl35bZg=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    # git dependency: the pinned GPUI fork
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [ pkg-config makeWrapper python3 ];
  buildInputs = [
    fontconfig glib gdk-pixbuf libglvnd libxcb libxkbcommon wayland
    vulkan-loader libheif mpv-unwrapped poppler
  ];

  # Upstream's test suite needs bwrap namespaces / O_TMPFILE; skip in the sandbox.
  doCheck = false;

  cargoBuildFlags = [ "--workspace" "--bins" ];

  # Cargo's own install step only handles the root crate; do the layout by hand.
  postInstall = ''
    install -Dm755 target/release/flea-gui $out/bin/flea-gui 2>/dev/null || true
    install -Dm755 tools/flea-gio-auth $out/lib/flea/flea-gio-auth
    install -Dm755 tools/flea-udisks $out/lib/flea/flea-udisks
    install -Dm755 tools/flea-portal $out/lib/flea/flea-portal
    install -Dm755 tools/flea-filemanager1 $out/lib/flea/flea-filemanager1
    install -Dm755 tools/flea-mpris $out/lib/flea/flea-mpris
    install -Dm644 packaging/com.thisisgm.flea.desktop -t $out/share/applications
    install -Dm644 packaging/com.thisisgm.flea.svg -t $out/share/icons/hicolor/scalable/apps
    install -Dm644 LICENSE THIRD-PARTY-LICENSES.txt -t $out/share/licenses/flea
    for catalog in i18n/*/flea.json; do
      install -Dm644 "$catalog" "$out/share/flea/$catalog"
    done

    substituteInPlace $out/share/applications/com.thisisgm.flea.desktop \
      --replace-quiet /usr/bin/flea $out/bin/flea

    for b in flea flea-gui; do
      [ -e $out/bin/$b ] && wrapProgram $out/bin/$b \
        --prefix PATH : ${lib.makeBinPath [ bat bubblewrap expect jq quickjs-ng ripgrep util-linux wl-clipboard xdg-utils udisks ]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libglvnd vulkan-loader wayland libxkbcommon fontconfig gdk-pixbuf libheif mpv-unwrapped poppler glib ]} \
        --prefix XDG_DATA_DIRS : ${shared-mime-info}/share
    done
  '';

  meta = {
    description = "Fast, keyboard-first file manager (built for Omarchy)";
    homepage = "https://github.com/thisisgm/flea";
    license = lib.licenses.mit;
    mainProgram = "flea";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
