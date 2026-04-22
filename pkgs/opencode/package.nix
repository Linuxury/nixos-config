# Prebuilt binary derivation for opencode.
#
# nixpkgs builds opencode from source (bun + node_modules fixed-output
# derivation) which requires manual hash updates for every release.
# opencode ships daily and nixpkgs can't keep up, so we fetch the
# prebuilt binary from the opencode-linux-x64 npm package instead.
#
# The binary is a Bun standalone executable. On NixOS this requires
# programs.nix-ld.enable = true (set in modules/base/ai-tools.nix) so
# that /lib64/ld-linux-x86-64.so.2 exists as a shim. Patching with
# patchelf or invoking through the interpreter both break Bun because
# it reads /proc/self/exe to locate its embedded JS.
#
# To update: change version + re-run to get new hash:
#   nix-prefetch-url --type sha256 \
#     https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-<ver>.tgz
#   nix hash convert --hash-algo sha256 --to sri <result>
{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  ripgrep,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.14.20";

  src = fetchurl {
    url = "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-${finalAttrs.version}.tgz";
    hash = "sha256-LRjasyNZ9rMzsLLZPO4PApbvlS7H+bM+FGgNiGmbnpY=";
  };

  nativeBuildInputs = [ makeBinaryWrapper ];

  # The fixup phase strips binaries by default. Bun standalone binaries
  # embed the application JS after the ELF content — stripping removes it,
  # causing Bun to fall back to its own CLI instead of running opencode.
  dontStrip = true;

  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    install -Dm755 package/bin/opencode $out/bin/.opencode-unwrapped
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
