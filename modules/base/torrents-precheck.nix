# ===========================================================================
# modules/base/torrents-precheck.nix — Fast-fail for Torrents automount
#
# Problem: COSMIC Files (and other apps) probe favorites paths on startup.
# /mnt/Torrents is a CIFS automount pointing to Radxa-X4, which is not
# always online. When offline, mount.cifs hangs for the full TCP SYN
# timeout (~120s). COSMIC Files retries the probe repeatedly during
# init, multiplying the delay to 60–90s of total blocking.
#
# Fix — two-layered:
#   1. Pre-check service: test port 445 with nc -w 1 before attempting
#      the CIFS mount. Fails in ~1s when Radxa-X4 is unreachable.
#   2. Start limit on the mount unit: after 2 fast failures within 60s,
#      subsequent automount requests get an immediate error (no new mount
#      attempt), so COSMIC Files unblocks after ~2s total instead of ~80s.
#
# Auto-activates: only applied when /mnt/Torrents is in fileSystems.
# No-op on hosts without the mount (servers, Alex machines if removed, etc.)
# ===========================================================================

{ config, pkgs, lib, ... }:

lib.mkIf (config.fileSystems ? "/mnt/Torrents") {

  # Oneshot service: probe Radxa-X4 port 445 with a 1s timeout.
  # Fails fast when the server is unreachable; succeeds in <1s on LAN.
  # The mount unit requires this to pass before calling mount.cifs.
  systemd.services.radxa-smb-check = {
    description = "Check Radxa-X4 SMB connectivity before mounting";
    serviceConfig = {
      Type            = "oneshot";
      ExecStart       = "${pkgs.netcat-openbsd}/bin/nc -z -w 1 10.0.0.5 445";
      RemainAfterExit = false;
    };
    unitConfig = {
      DefaultDependencies = "no";
    };
    # Rate-limit the check itself — don't hammer the network
    startLimitIntervalSec = 30;
    startLimitBurst       = 5;
  };

  # Drop-in for the generated mnt-Torrents.mount unit:
  #   - Require the connectivity check to pass before mounting
  #   - StartLimitBurst=2: after 2 failures in 60s, return immediate
  #     errors to callers (automount releases waiting processes instantly)
  #     instead of triggering another slow mount attempt
  environment.etc."systemd/system/mnt-Torrents.mount.d/precheck.conf".text = ''
    [Unit]
    Requires=radxa-smb-check.service
    After=radxa-smb-check.service
    StartLimitIntervalSec=60
    StartLimitBurst=2
  '';

}
