# ===========================================================================
# modules/gaming/gaming.nix — Gaming stack
#
# This module sets up everything needed for a great Linux gaming experience.
# It pulls bleeding edge versions from nixpkgs-unstable since gaming tools
# move fast and you want the latest Proton, Mesa, and driver updates.
#
# Enable this module on any host where gaming is needed:
#   - Your machines
#   - Wife's machines
#   - Kid's machines
#
# Servers never need this.
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  # =========================================================================
  # Steam
  #
  # Steam needs special handling in NixOS because it's a 32-bit app that
  # manages its own runtime. The NixOS Steam module handles all of this
  # cleanly — don't try to just add steam to systemPackages.
  # =========================================================================
  programs.steam = {
    enable = true;

    # Opens firewall ports for Steam Remote Play and In-Home Streaming
    remotePlay.openFirewall = true;

    # Opens firewall ports for Steam's game server browser
    dedicatedServer.openFirewall = true;

    # Adds a compatibility layer so Steam's own runtime libraries
    # work correctly on NixOS's non-standard filesystem layout
    package = pkgs.steam.override {
      extraPkgs = steamPkgs: with steamPkgs; [
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
      ];
    };
  };

  # =========================================================================
  # GameMode — Performance optimizer
  #
  # GameMode is a daemon that temporarily optimizes system performance
  # when a game starts. It does things like:
  #   - Switch CPU governor to performance mode
  #   - Increase process priority for the game
  #   - Disable power saving features temporarily
  #
  # Games can request it automatically, or you can launch with:
  #   gamemoderun <game>
  # Steam launch options: gamemoderun %command%
  # =========================================================================
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;          # Boost game process priority
        softrealtime = "auto"; # Enable soft realtime scheduling if possible
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;       # Primary GPU (change to 1 for secondary)
        amd_performance_level = "high"; # AMD GPU performance mode during gaming
      };
      custom = {
        # Commands to run when GameMode starts and stops
        # Useful for disabling notifications while gaming
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Optimizations applied'";
        end   = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Optimizations removed'";
      };
    };
  };

  # =========================================================================
  # MangoHud — In-game performance overlay
  #
  # Shows FPS, GPU/CPU usage, temperatures, and frame times as an
  # overlay inside games. Very useful for monitoring performance.
  #
  # Enable per game in Steam launch options with:
  #   MANGOHUD=1 %command%
  # Or globally with: mangohud <game>
  # =========================================================================
  # programs.mangohud.enable = true;  # not a NixOS module option; mangohud
  #                                   # is already in systemPackages below

  # =========================================================================
  # Gaming packages
  # =========================================================================
  environment.systemPackages = with pkgs; [

    # -----------------------------------------------------------------------
    # Launchers — for games outside of Steam
    # -----------------------------------------------------------------------
    heroic          # Epic Games Store + GOG launcher for Linux
    lutris          # Universal game launcher, supports many sources
                    # and has community install scripts for tricky games

    # -----------------------------------------------------------------------
    # Proton / Wine — Windows game compatibility layers
    # -----------------------------------------------------------------------
    protonplus      # Manage Proton-GE and other compatibility tools
                    # Run after first boot to install latest Proton-GE

    wine-staging    # Latest Wine with extra patches for better compatibility
    winetricks      # Installs Windows libraries/runtimes needed by some games

    # -----------------------------------------------------------------------
    # Utilities
    # -----------------------------------------------------------------------
    gamemode        # CLI access to GameMode (already enabled above)
    mangohud        # CLI access to MangoHud (already enabled above)

    vulkan-tools    # vulkaninfo — useful for checking Vulkan is working
    mesa-demos      # glxinfo, glxgears — check OpenGL info and verify drivers

    # Controller support
    antimicrox      # Map controller buttons to keyboard/mouse
                    # Useful for games with no controller support

    # Discord — for gaming with friends
    discord

    # -----------------------------------------------------------------------
    # Minecraft — all three family members play
    # -----------------------------------------------------------------------
    prismlauncher       # Java Minecraft launcher — manages its own Java runtimes
                        # Set up each user's Mojang account in Prism after first boot
    mcpelauncher-ui-qt  # Minecraft Bedrock Edition launcher
    jdk17               # Java 17 runtime — required for Minecraft 1.17 and newer
                        # Prism manages older Java versions internally for legacy versions
  ];

  # =========================================================================
  # Controller support — udev rules
  #
  # Without these rules, controllers need root access to be read.
  # This gives your user permission to use controllers without sudo.
  # Covers PlayStation, Xbox, Nintendo Switch Pro, and generic controllers.
  # =========================================================================
  services.udev.packages = with pkgs; [
    game-devices-udev-rules
  ];

  # =========================================================================
  # Kernel parameters for better gaming performance
  #
  # These are well-known tweaks that reduce stuttering and improve
  # frame pacing in games.
  # =========================================================================
  boot.kernel.sysctl = {
    # Increase max map count — required by some games (notably DOTA 2)
    # and helps with memory management under gaming workloads
    "vm.max_map_count" = 2147483642;
  };
}
