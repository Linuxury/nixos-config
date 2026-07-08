# ===========================================================================
# modules/gaming/default.nix — Gaming stack
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
}:
let
  # =========================================================================
  # steam-bpm — Big Picture Mode launcher
  #
  # Shuts down Desktop Mode Steam (if running), detects the active monitor's
  # native resolution and refresh rate, then launches Steam Big Picture Mode
  # wrapped inside a gamescope nested session.
  #
  # Why gamescope here: Steam's BPM uses gamescope --steam internally, which
  # expects to own a display (standalone compositor mode). Running it nested
  # inside Hyprland without this wrapper causes a black screen because
  # gamescope can't take over the display. Wrapping it ourselves puts gamescope
  # in nested mode where it renders correctly as a Hyprland window.
  #
  # Trigger: SUPER+CTRL+B keybind → lands on WS 2 via existing gamescope rule.
  # =========================================================================
  steamBpm = pkgs.writeShellScriptBin "steam-bpm" ''
    # Shut down Desktop Mode Steam if it's already running
    if pgrep steam > /dev/null 2>&1; then
      steam -shutdown 2>/dev/null || true
      sleep 2
    fi

    # Detect active monitor's native resolution and refresh rate
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
      read -r W H R < <(hyprctl monitors -j | python3 -c "
import json, sys
monitors = json.load(sys.stdin)
m = next((m for m in monitors if m['focused']), monitors[0])
print(m['width'], m['height'], round(m['refreshRate']))
")
    else
      read -r W H R < <(xrandr --current | python3 -c "
import sys, re
content = sys.stdin.read()
primary = re.search(r'(\d+)x(\d+)\+0\+0', content)
if primary:
    W, H = primary.group(1), primary.group(2)
    after = content[primary.start():]
    hz = re.search(r'(\d+\.\d+)\*', after)
    if hz:
        print(W, H, round(float(hz.group(1))))
")
    fi

    exec gamescope -W "$W" -H "$H" -w "$W" -h "$H" -r "$R" -e -- steam -gamepadui
  '';
in
{
  imports = [
    ./dmemcg-booster/default.nix
  ];

  # =========================================================================
  # Gaming-only overlays — scoped here so headless hosts never fetch these
  # source tarballs during evaluation.
  #
  # proton-ge-custom and goverlay use inline pkgs.fetchzip (not flake inputs)
  # so headless servers never resolve these tarballs when building from GitHub.
  # nru updates the URL, version, and hash in this file directly.
  # =========================================================================
  nixpkgs.overlays = [
    (final: prev: {
      proton-ge-custom = prev.callPackage ../../pkgs/proton-ge-custom/package.nix {
        proton-ge-src = pkgs.fetchzip {
          url  = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-1/GE-Proton11-1.tar.gz"; # proton-ge-nru
          hash = "sha256-I7SSvzQQ/NqdvwjpJ9IFFtAaTS+rgHUyXx0us1vIOnw="; # proton-ge-hash
        };
      };

      # GOverlay — pinned ahead of nixpkgs; nru keeps the version current.
      # All build inputs (lazarus-qt6, fpc, etc.) are inherited from prev.goverlay.
      #
      # 1.8.4 added pascube as a bundled binary (pascube_src/pascube.lpi).
      # The upstream Makefile install target expects it but has a bug: it doesn't
      # list pascube_bin as a prerequisite of install, so make install runs without
      # building it. We extend buildPhase to build and copy it manually.
      goverlay = prev.goverlay.overrideAttrs (old:
        let mangohudBin = prev.lib.getExe' prev.mangohud "mangohud"; in
        {
          version = "1.8.6"; # goverlay-nru
          src     = pkgs.fetchzip {
            url  = "https://github.com/benjamimgois/goverlay/archive/refs/tags/1.8.6.tar.gz"; # goverlay-nru
            hash = "sha256-oPte8wDXF6bzD6eNP5O/iubwQ8l7pf+W7TJeouRJVlY="; # goverlay-hash
          };
          # pascube (new in 1.8.4) links against SDL2 — not needed by goverlay itself.
          buildInputs = old.buildInputs ++ [ prev.SDL2 ];
          buildPhase = old.buildPhase + ''
            HOME=$(mktemp -d) lazbuild --lazarusdir=${prev.lazarus-qt6}/share/lazarus -B pascube_src/pascube.lpi
            cp pascube_src/pascube ./pascube
          '';
          # goverlay.sh.in in 1.8.4 unconditionally calls `mangohud ./goverlay`
          # (LD_PRELOAD injection) which aborts on NixOS — wrapQtAppsHook doesn't
          # wrap the Lazarus ELF so qtWrapperArgs is ineffective here.
          # Fix: uncomment QT_QPA_PLATFORM=xcb and strip the mangohud wrapper,
          # calling the goverlay ELF directly instead.
          postPatch = old.postPatch + ''
            sed -i 's|^#export QT_QPA_PLATFORM=xcb|export QT_QPA_PLATFORM=wayland\nunset QT_QPA_PLATFORMTHEME|' data/goverlay.sh.in
            sed -i 's|${mangohudBin} @libexecdir@/goverlay|@libexecdir@/goverlay|' data/goverlay.sh.in
          '';
        });
    })
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

    # Proton-GE — prebuilt release tarball, updated automatically via nru
    extraCompatPackages = [ pkgs.proton-ge-custom ];

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
  # GameMode polkit rule — allow members of the "gamemode" group to run
  # gamemoded's helper binaries (cpugovctl, gpuclockctl, cpucorectl,
  # procsysctl) without a password prompt.
  #
  # On NixOS the gamemode package can end up at two different store paths
  # (one for the system polkit actions, one for the user service closure).
  # When the binary path doesn't match the annotation in the .policy file,
  # polkit falls back to the generic org.freedesktop.policykit.exec action
  # instead of com.feralinteractive.GameMode.*. Matching by helper name
  # (not store path) avoids this hash-mismatch problem.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var helpers = ["cpugovctl", "gpuclockctl", "cpucorectl", "procsysctl"];
      if (action.id === "org.freedesktop.policykit.exec" &&
          subject.isInGroup("gamemode")) {
        var prog = action.lookup("program") || "";
        for (var i = 0; i < helpers.length; i++) {
          if (prog.indexOf(helpers[i]) !== -1) {
            return polkit.Result.YES;
          }
        }
      }
    });
  '';

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
    # Graphics compatibility / post-processing
    # -----------------------------------------------------------------------
    vkbasalt # Vulkan post-processing layer — FSR1, CAS sharpening, SMAA,
    # FXAA applied to any Vulkan game without touching launch options.
    # GOverlay has a dedicated config tab for it (needs the package installed).

    gamescope-wsi # Vulkan WSI layer that ships separately from the gamescope
    # binary. Required for gamescope HDR and frame-timing features to work
    # inside running games on Wayland.

    # -----------------------------------------------------------------------
    # Launchers — non-Steam storefronts
    # -----------------------------------------------------------------------
    heroic # Epic Games + GOG launcher — wraps Proton/Wine the same way
    # Steam does; uses UMU internally for compatibility.

    umu-launcher # Valve's universal compatibility tool (umu-run <exe>).
    # Faugus-launcher pulls this in transitively, but having it explicitly
    # lets you run any non-Steam EXE with Proton from the CLI.

    steam-run # Run arbitrary Linux binaries inside Steam's FHS sandbox.
    # Some game launchers and tools require a standard FHS layout which
    # NixOS doesn't provide by default — this wraps any binary cleanly.

    # Controller support
    antimicrox # Map controller buttons to keyboard/mouse
    # Useful for games with no controller support

    # Steam Big Picture Mode launcher (gamescope-wrapped, see let block above)
    steamBpm

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
    # Flathub is already configured via system/graphical/default.nix activation script.
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
  # pressure-vessel (Valve's container runtime used by umu-launcher / Faugus)
  # probes bubblewrap by exec-ing `true`. On NixOS /bin/true doesn't exist —
  # this symlink satisfies the probe without touching the global FHS compat layer.
  system.activationScripts.bwrapBinTrue = lib.stringAfter [ "users" ] ''
    mkdir -p /bin
    [ -e /bin/true ] || ln -sf ${pkgs.coreutils}/bin/true /bin/true
  '';

  boot.kernelModules = ["ntsync" "uinput"];
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
