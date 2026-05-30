# ===========================================================================
# modules/gaming/dmemcg-booster/default.nix — VRAM cgroup priority service
#
# dmemcg-booster is a systemd service by Valve engineer Natalie Vock that
# uses the kernel's DRM device memory cgroup controller (dmemcg) to protect
# the foreground game's VRAM from being evicted by background processes.
#
# Without this, Linux has no concept of priority — a browser or compositor
# can silently steal VRAM from a running game, causing stutters and GTT
# spilling on GPUs with 8 GB or less.
#
# KERNEL REQUIREMENT: Linux 7.0+ with the dmemcg patches (included in
# XanMod 7.0 and CachyOS kernels). On older kernels the service starts
# harmlessly but does nothing.
#
# This module provides the DE-agnostic system daemon. DE-specific
# foreground-booster integrations (e.g. plasma-foreground-booster for KDE)
# sit on top of this and tell the daemon which window is currently focused.
#
# Source: https://github.com/ngoquang2708/dmemcg-booster
#         (mirror of upstream gitlab.steamos.cloud/holo/dmemcg-booster)
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  dmemcg-booster = pkgs.rustPlatform.buildRustPackage {
    pname = "dmemcg-booster";
    version = "0.1.2";

    src = pkgs.fetchFromGitHub {
      owner = "ngoquang2708";
      repo  = "dmemcg-booster";
      rev   = "79de901c077fedf2b3be53b460e4be8c16eaf020";
      hash  = "sha256-qETBTccMJmB5IJPBK1sLTUdtpPfLFMKFwewLqpB/PgM=";
    };

    cargoHash = "sha256-dIWUQoHB2nFvHvaq3aDWItifFKHBsJ6EJjIbrM/prIw=";

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs       = [ pkgs.dbus ];
  };

in {
  options.services.dmemcg-booster = {
    enable = lib.mkEnableOption "dmemcg-booster VRAM cgroup priority service";
  };

  config = lib.mkIf config.services.dmemcg-booster.enable {

    systemd.services.dmemcg-booster = {
      description = "dmemcg-booster — VRAM cgroup priority for foreground games";
      wantedBy    = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart    = "${dmemcg-booster}/bin/dmemcg-booster --use-system-bus";
        Restart      = "on-failure";
        RestartSec   = "5s";
      };
    };

  };
}
