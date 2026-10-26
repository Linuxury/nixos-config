# ===========================================================================
# modules/system/build-capacity.nix — per-host nix build parallelism
#
# Imported by modules/system/core/default.nix, so every host gets it.
#
# Why this exists: `max-jobs` and `cores` govern different axes, and setting
# one flat pair fleet-wide gets both wrong.
#
#   cores     — parallelism INSIDE one derivation (make -j). The MEMORY knob:
#               it is what multiplies into RAM. cores = 0 means "all of them",
#               so max-jobs × nproc compilers can run at once. On a 16-thread
#               host with 14 GB that is 32 compilers ≈ 32 GB — an OOM kill.
#   max-jobs  — how many derivations run AT ONCE. The THROUGHPUT knob: a
#               rebuild is mostly a long tail of small single-threaded
#               derivations, and a low max-jobs leaves most cores idle.
#
# So: cap total threads by RAM, pick max-jobs for throughput, divide to get
# cores. Specs come from hosts/<host>/specs.nix, written once by
# scripts/host-specs.sh and committed — nix eval is pure and cannot read
# /proc, so detection happens out of band and the result lives in git where
# dry-build can check it.
#
# No specs.nix (unprobed, or deliberately old hardware like the Alex hosts)
# selects the floor tier. That is a decision, not an accident: those machines
# almost never compile anything, because nearly every path arrives as a
# substitute from cache.nixos.org — so surviving an unexpected 3am build
# matters more than its speed.
#
# Note these hosts deliberately do NOT set nix.settings.fallback. On a floor
# tier host that would force a local source build whenever substitution
# fails, which is the exact scenario this module exists to prevent. fallback
# is set only where a remote builder makes it safe — see
# modules/system/remote-builder.nix.
#
# Both values are mkDefault — any host can override in its own file.
# ===========================================================================

{ lib, hostname, ... }:

let
  specFile = ../../hosts/${hostname}/specs.nix;
  spec = if builtins.pathExists specFile then import specFile else null;

  # Deliberately below Radxa-X4 (4c/7G → 1 × 4), per plan.
  floor = { jobs = 1; cores = 2; };

  # ~0.75 GB of RAM per build thread. This cap is what keeps core-rich,
  # RAM-poor hosts safe (ThinkPad: 10 threads on 14 GB, not 16).
  threads = lib.min spec.cores ((spec.ramGB * 3) / 4);
  # At most 2 slots, and each gets ALL the RAM-safe threads — not a share.
  # A rebuild is one or two big compiles plus many sub-second derivations;
  # splitting threads across 5 slots (the first version of this file) left
  # noctalia compiling on 4 of 24 threads while the other slots sat idle.
  # Measured 2026-10-23 on Ryzen5900x (noctalia + umbriel at once, 2 × 23):
  # 294 s vs 727 s at the old 5 × 4, peaking at 24 GB of 32 — ~0.5 GB per
  # thread — but that left ~7 GB for the desktop, and on 2026-10-26 the same
  # pair OOM-killed cc1plus. So a second slot only when the RAM budget covers
  # BOTH full-width slots; otherwise one (the sub-second derivations barely
  # notice serializing).
  jobs = if (spec.ramGB * 3) / 4 >= 2 * threads then 2 else 1;

  cap = if spec == null then floor else {
    inherit jobs;
    cores = lib.max 1 threads;
  };
in
{
  nix.settings = {
    max-jobs = lib.mkDefault cap.jobs;
    cores    = lib.mkDefault cap.cores;   # never 0 — see header
  };
}
