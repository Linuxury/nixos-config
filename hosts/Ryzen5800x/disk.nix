# ===========================================================================
# hosts/Ryzen5800x/disk.nix — disks, swap, LUKS and boot loader for Ryzen5800x
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
      options = [ "subvol=@" "compress=zstd:1" "noatime" ];
    };
    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd:1" "noatime" ];
    };
    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd:1" "noatime" ];
    };
    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd:1" "noatime" ];
    };
    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@cache" "compress=zstd:1" "noatime" ];
    };
    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd:1" "noatime" ];
    };
    "/home/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@home_snapshots" "compress=zstd:1" "noatime" ];
    };
    # Steam's own subvolume — kept out of @home so /home btrfs snapshots
    # never pin the 100s of GB a game library churns through. Snapper has
    # no per-path exclude; a sibling subvolume boundary is the only real
    # mechanism (same trick as @cache above).
    "/home/babylinux/.local/share/Steam" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@steam" "compress=zstd:1" "noatime" ];
    };
    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@swap" "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    # -----------------------------------------------------------------------
    # Local NTFS HDD — former Windows drive, now used as storage
    # Uses the ntfs3 in-kernel driver (faster than FUSE ntfs-3g).
    # force: mounts even if Windows left the dirty/hibernation flag set.
    # -----------------------------------------------------------------------
    "/mnt/Warehouse" = {
      device  = "/dev/disk/by-label/Warehouse";
      fsType  = "ntfs3";
      options = [
        "uid=${toString config.users.users.babylinux.uid}" "gid=100"
        "umask=007"
        "nofail" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=10s"
        "force"
      ];
    };
  };

  # ==============================================================
  # Swap
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];
}
