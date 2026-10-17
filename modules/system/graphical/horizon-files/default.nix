# ===========================================================================
# modules/system/graphical/horizon-files/default.nix — Horizon File Manager
#
# Wayland-native file manager from the Event Horizon desktop
# (https://github.com/Event-Horizon-desktop-environment/Horizon-File-Manager).
# Installed as an alternate: Nautilus/Thunar stay, and the inode/directory
# default is not touched. Built from the horizon-files flake input in
# pkgs/horizon-files/package.nix.
#
# Making it THE default file manager: uncomment the three marked lines below
# (FileManager1 service, hiPrio, folder default). All three, not just one —
# otherwise Nautilus keeps "Show in folder" or Thunar keeps opening folders.
#
# Overlay is scoped here, so only hosts importing this module build it.
# ===========================================================================

{ inputs, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      horizon-files = prev.callPackage ../../../../pkgs/horizon-files/package.nix {
        src = inputs.horizon-files;
        # [default FM 1/3] keep its org.freedesktop.FileManager1 D-Bus service
        # (browsers' "Show in folder" opens Horizon with the file selected).
        # withFileManager1 = true;
      };
    })
  ];

  environment.systemPackages = [
    pkgs.horizon-files
    # [default FM 2/3] Nautilus ships the same FileManager1 service file; hiPrio
    # makes Horizon's copy win in the system profile. Replace the line above.
    # (lib.hiPrio pkgs.horizon-files)
  ];

  # [default FM 3/3] open folders with Horizon for every user on this host.
  # mkOverride 40 beats the mkForce (50) in modules/system/graphical/thunar.
  # home-manager.sharedModules = [{
  #   xdg.mimeApps.defaultApplications."inode/directory" = lib.mkOverride 40 "horizon-files.desktop";
  # }];
}
