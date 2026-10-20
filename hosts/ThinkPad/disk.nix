# ===========================================================================
# hosts/ThinkPad/disk.nix — disks, swap, LUKS and boot loader for ThinkPad
#
# Split out of default.nix so the installer can (re)write this file for a
# new disk layout without touching the rest of the host config. Network
# shares and pooled mounts (cifs, mergerfs) stay in default.nix.
# ===========================================================================
{ config, lib, pkgs, ... }:

{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@home"
        "compress=zstd:1"
        "noatime"
      ];
    };
    # Steam's own subvolume — kept out of @home so /home btrfs snapshots
    # never pin the 100s of GB a game library churns through. Snapper has
    # no per-path exclude; a sibling subvolume boundary is the only real
    # mechanism.
    "/home/linuxury/.local/share/Steam" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@steam" "compress=zstd:1" "noatime" ];
    };
    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@nix"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@log"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@cache"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@snapshots"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/home/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@home_snapshots"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@swap"
        "noatime"
      ];
      # No compression on swap — compressed swap causes issues
    };
    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
      # Restrictive permissions on /boot for security
    };
  };

  # ==============================================================
  # LUKS — Full disk encryption
  #
  # The BTRFS partition sits inside a LUKS container.
  # You'll be prompted for this passphrase before the system boots.
  # The label "nixos-luks" refers to the raw encrypted partition.
  # After unlocking, it becomes available as /dev/mapper/cryptroot
  # which is where our BTRFS filesystem lives.
  # ==============================================================
  boot.initrd.luks.devices."cryptroot" = {
    # We reference by label so it works regardless of whether the drive
    # is nvme0n1, nvme1n1, or any other device name
    device = "/dev/disk/by-label/nixos-luks";
    allowDiscards = true;
    # Enables TRIM on the SSD through LUKS
    # Important for SSD longevity and performance
  };

  # ==============================================================
  # Swap
  # ==============================================================
  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];
}
