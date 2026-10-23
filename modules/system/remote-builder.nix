# ===========================================================================
# modules/system/remote-builder.nix — offload Nix builds to MinisForum
#
# Importing this file IS the opt-in; there is no enable flag. Currently
# imported by Radxa-X4 only: a 2026-10-23 stress test (noctalia + umbriel)
# showed ThinkPad (584 s) and Media-Server (562 s) build locally as fast as
# MinisForum does remotely (~627 s); Radxa-X4 takes 2283 s on its own.
#
# Why: modules/system/build-capacity.nix caps each host's parallelism to what
# its RAM survives, which fixed the rebuild OOMs but left the weak hosts
# deliberately slow (Radxa-X4 at 1 x 4 on 7 GB). MinisForum is online 24/7
# with 16c/31G, so it absorbs the heavy derivations instead.
#
# Trust: the key below logs into `nixbuilder` on MinisForum, which is a
# trusted-user there — it can insert arbitrary paths into that host's store.
# That makes this key root-equivalent ON THE BUILDER, which is why it is NOT
# deployed to the Alex machines. See secrets/secrets.nix.
#
# The builder is NOT a single point of failure: max-jobs stays whatever
# build-capacity.nix derived (never 0), and `fallback` lets a host build
# locally when MinisForum is unreachable.
# ===========================================================================

{ config, ... }:

{
  # Private half of the fleet-builder keypair. nix-daemon runs as root, so
  # root must own it; agenix defaults to root but it is spelled out here to
  # match the pattern in hosts/Radxa-X4/default.nix.
  age.secrets.nix-builder-key = {
    file  = ../../secrets/nix-builder-key.age;
    mode  = "0400";
    owner = "root";
  };

  # Pin the builder's host key declaratively instead of relying on
  # StrictHostKeyChecking=accept-new on first contact. Writes
  # /etc/ssh/ssh_known_hosts, which root's ssh reads. Preferred over
  # buildMachines.publicHostKey, whose base64 encoding is easy to get wrong.
  # The attribute name IS the matched hostname, which is exactly the name
  # buildMachines dials below. Value is MinisForum's host key, already
  # recorded in secrets/secrets.nix.
  programs.ssh.knownHosts.minisforum.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/HPvxQY35jS4VDZRy4viIfHIGjUqkCgFhRVNcIsZRG";

  nix = {
    distributedBuilds = true;

    buildMachines = [{
      # Tailscale MagicDNS resolves this system-wide, not just via a user's
      # ~/.ssh/config, so nix-daemon (root) reaches it by name on LAN or away.
      hostName   = "minisforum";
      sshUser    = "nixbuilder";
      sshKey     = config.age.secrets.nix-builder-key.path;
      protocol   = "ssh-ng";
      systems    = [ "x86_64-linux" ];

      # Matches MinisForum's own 2 x 16; each remote build gets 16 threads,
      # and the idle CPU/IO scheduling keeps Crafty (Minecraft) responsive.
      maxJobs = 2;
      # speedFactor left at its default — it only orders builders relative to
      # each other, and MinisForum is the only one.

      # big-parallel is the one that matters: it is what lets the large
      # packages — the ones that used to OOM these hosts — go remote. kvm
      # covers anything needing /dev/kvm.
      supportedFeatures = [ "big-parallel" "kvm" ];
    }];

    settings = {
      # The builder fetches from cache.nixos.org itself rather than having
      # substitutes proxied through the weak client's uplink.
      builders-use-substitutes = true;

      # Build locally if MinisForum is unreachable, instead of failing the
      # rebuild outright. This is what keeps one builder from becoming a
      # single point of failure — and what build-capacity.nix's header
      # assumes when it justifies the floor tier.
      fallback = true;
    };
  };
}
