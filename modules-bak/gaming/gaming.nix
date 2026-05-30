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
{
  config,
  pkgs,
  lib,
  ...
}: let
  # ===========================================================================
  # OptiScaler Client — GUI manager for the OptiScaler upscaling injector
  #
  # OptiScaler shims FSR/DLSS/XeSS upscaling into games that don't natively
  # support your preferred API. This client manages installation and
  # configuration across Steam, Epic, GOG, and EA game libraries.
  #
  # Self-contained .NET single-file bundle — the entire runtime + assemblies
  # are packed inside the ELF binary using an offset table appended at the end.
  # autoPatchelfHook would resize the binary to fix ELF paths, invalidating
  # those offsets → "Arithmetic overflow while reading bundle" at startup.
  #
  # Fix: never touch the binary. Use buildFHSEnv to provide the FHS paths
  # (/lib, /lib64, /usr/lib) that the binary's hardcoded interpreter expects.
  # ===========================================================================
  optiscaler-client-bin = pkgs.stdenv.mkDerivation rec {
    pname = "optiscaler-client-bin";
    version = "1.0.5";

    src = pkgs.fetchurl {
      url = "https://github.com/Agustinm28/Optiscaler-Client/releases/download/OptiscalerClient-${version}/OptiscalerClient-${version}-linux-x64.tar.gz";
      sha256 = "12wlifm40x5rkail6b2098c375b6s3948xszqzni7zf84zfndbys";
    };

    sourceRoot = ".";
    dontBuild = true;
    dontFixup = true; # critical — prevents any ELF patching that corrupts the bundle

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/optiscaler-client
      cp -r . $out/lib/optiscaler-client/
      chmod +x $out/lib/optiscaler-client/OptiscalerClient
      runHook postInstall
    '';
  };

  optiscaler-client = pkgs.buildFHSEnv {
    name = "optiscaler-client";

    # Libraries provided inside the FHS sandbox — Avalonia UI + .NET deps
    targetPkgs = _: with pkgs; [
      libX11
      libXext
      libXrandr
      libXcursor
      libXi
      libICE
      libSM
      fontconfig
      freetype
      zlib
      openssl
      icu
      libGL
      stdenv.cc.cc.lib
    ];

    # Script run inside the FHS environment
    runScript = pkgs.writeShellScript "optiscaler-client" ''
      export DOTNET_BUNDLE_EXTRACT_BASE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/optiscaler-client"
      exec ${optiscaler-client-bin}/lib/optiscaler-client/OptiscalerClient "$@"
    '';

    # Desktop entry lives outside the FHS wrapper
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cat > $out/share/applications/optiscaler-client.desktop <<EOF
      [Desktop Entry]
      Name=OptiScaler Client
      Comment=Manage OptiScaler upscaling across your game libraries
      Exec=optiscaler-client
      Type=Application
      Categories=Game;Utility;
      Keywords=upscaling;fsr;dlss;xess;optiscaler;
      EOF
    '';

    meta = with lib; {
      description = "GUI manager for OptiScaler — injects FSR/DLSS/XeSS upscaling into any game";
      homepage = "https://github.com/Agustinm28/Optiscaler-Client";
      platforms = ["x86_64-linux"];
    };
  };
in
{
  imports = [
    ./dmemcg-booster.nix
  ];

  services.dmemcg-booster.enable = true;
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
      extraPkgs = steamPkgs:
        with steamPkgs; [
          alsa-lib
          libxcursor
          libxi
          libxinerama
          libxscrnsaver
          libpng
          libpulseaudio
          libvorbis
          libglvnd
          stdenv.cc.cc.lib
          libkrb5
          keyutils
          SDL2
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
        renice = 10; # Boost game process priority
        softrealtime = "auto"; # Enable soft realtime scheduling if possible
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0; # Primary GPU (change to 1 for secondary)
        amd_performance_level = "high"; # AMD GPU performance mode during gaming
      };
      custom = {
        # Commands to run when GameMode starts and stops
        # Useful for disabling notifications while gaming
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Optimizations applied'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Optimizations removed'";
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
    lutris # Universal game launcher, supports many sources
    # and has community install scripts for tricky games
    faugus-launcher # Lightweight launcher for Windows games via UMU/Proton

    # -----------------------------------------------------------------------
    # Proton / Wine — Windows game compatibility layers
    # -----------------------------------------------------------------------
    protonplus # Manage Proton-GE and other compatibility tools
    # Run after first boot to install latest Proton-GE

    wine-staging # Latest Wine with extra patches for better compatibility
    winetricks # Installs Windows libraries/runtimes needed by some games
    protontricks # Winetricks wrapper for Steam/Proton — handles the Proton
    # runtime paths automatically so you don't have to

    # -----------------------------------------------------------------------
    # Gamescope — Valve's gaming microcompositor
    #
    # Runs games in a nested compositor session. Lets you:
    #   - Force a game to render at a lower resolution and upscale
    #   - Cap framerate independently per game
    #   - Enable HDR output on supported displays
    #
    # Steam launch option: gamescope -W 2560 -H 1440 -- %command%
    # -----------------------------------------------------------------------
    gamescope

    # -----------------------------------------------------------------------
    # Utilities
    # -----------------------------------------------------------------------
    gamemode # CLI access to GameMode (already enabled above)
    mangohud # CLI access to MangoHud (already enabled above)
    goverlay # GUI configurator for MangoHud and vkBasalt overlays
    # Makes tweaking your overlay much easier than editing
    # the dotfile directly
    sgdboop # SteamGridDB asset manager — apply custom banners/icons
    # to Steam games from SteamGridDB with one click

    vulkan-tools # vulkaninfo — useful for checking Vulkan is working
    mesa-demos # glxinfo, glxgears — check OpenGL info and verify drivers

    # -----------------------------------------------------------------------
    # OptiScaler Client — upscaling injector manager
    # -----------------------------------------------------------------------
    optiscaler-client # GUI manager for OptiScaler — shims FSR/DLSS/XeSS into
    # games that don't natively support your preferred upscaling API

    # Controller support
    antimicrox # Map controller buttons to keyboard/mouse
    # Useful for games with no controller support

    # -----------------------------------------------------------------------
    # Minecraft — all three family members play
    # -----------------------------------------------------------------------
    prismlauncher # Java Minecraft launcher — manages its own Java runtimes
    # Set up each user's Mojang account in Prism after first boot
    jdk17 # Java 17 runtime — required for Minecraft 1.17 and newer
    # Prism manages older Java versions internally for legacy versions

    # Bedrock Edition — managed via Flatpak (io.mrarm.mcpelauncher)
    # The nix package is incompatible with Bedrock 1.26.x on NixOS due to
    # a fundamental conflict between the Android linker and NixOS's non-FHS
    # library paths. The Flatpak version bundles its own libs and works correctly.
    # Flathub is already configured via graphical-base.nix activation script.
    # Users can install with: flatpak install flathub io.mrarm.mcpelauncher
  ];

  # =========================================================================
  # ntsync — NT synchronization primitives (kernel 6.14+)
  #
  # Exposes /dev/ntsync with proper udev rules so non-root users can use it.
  # Wine-staging and Proton-GE pick this up automatically for much lower
  # CPU overhead on synchronization-heavy Windows games.
  # No Steam launch option needed — Wine/Proton auto-detects it.
  # =========================================================================
  boot.kernelModules = ["ntsync"];
  services.udev.extraRules = ''
    KERNEL=="ntsync", TAG+="uaccess"
  '';

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
