# Stale upstream dependency hashes, applied by the hash-fixes overlay in flake.nix.
# Managed by nru: [F]ix adds an entry when a rebuild hits a hash mismatch, and
# removes it once nixpkgs catches up (the build then fails with the reverse
# mismatch). One entry per line — nru edits this file line by line.
{
  typescript-language-server = { attr = "pnpmDeps"; hash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4="; added = "2026-10-13"; };
}
