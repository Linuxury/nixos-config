# Prebuilt binary derivation for opencode.
#
# nixpkgs builds opencode from source (bun + node_modules fixed-output
# derivation) which requires manual hash updates for every release.
# opencode ships daily and nixpkgs can't keep up, so we fetch the
# prebuilt x64 Linux binary directly from GitHub releases and patch it
# for NixOS with autoPatchelfHook.
#
# To update: change version + re-run to get new hash:
#   nix-prefetch-url --type sha256 \
#     https://github.com/anomalyco/opencode/releases/download/v<ver>/opencode-linux-x64.tar.gz
#   nix hash convert --hash-algo sha256 --to sri <result>
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  glibc,
  ripgrep,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.14.20";

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${finalAttrs.version}/opencode-linux-x64.tar.gz";
    hash = "sha256-FwcTMCI4LqjIzFvEerHbUvoga9m6+NOtTYYrSJ27RI8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    glibc
  ];

  # The tarball contains a single `opencode` binary at the root
  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    install -Dm755 opencode $out/bin/.opencode-unwrapped
    makeWrapper $out/bin/.opencode-unwrapped $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencode";
  };
})
