{
  # ===========================================================================
  # flake.nix — The entry point of your entire NixOS configuration
  #
  # Think of this file as the "table of contents" for your whole system.
  # It does three main things:
  #   1. Declares WHERE to get packages from (inputs)
  #   2. Declares WHAT systems/hosts exist (outputs)
  #   3. Wires everything together
  #
  # Changes from previous version:
  #   - mkHost now accepts a wallpaperDir argument
  #   - wallpaperDir is passed into Home Manager via extraSpecialArgs
  #   - Each host passes the correct wallpaper folder for its user
  #   - Servers unchanged — no Home Manager, no wallpaper
  # ===========================================================================

  description = "Linuxury Family NixOS Configuration";

  # ===========================================================================
  # INPUTS — External sources this flake depends on
  #
  # Each input is a separate flake that gets "locked" in flake.lock.
  # The lock file remembers the exact version of each input so your system
  # is always reproducible. Run `nix flake update` to get newer versions.
  # ===========================================================================
  inputs = {

    # -------------------------------------------------------------------------
    # nixpkgs — The main package collection
    # We use "nixos-unstable" for bleeding edge packages across all hosts.
    # This is the source of almost every package you'll install.
    # -------------------------------------------------------------------------
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # -------------------------------------------------------------------------
    # home-manager — Manages per-user configuration and dotfiles
    # This lets us define each user's environment declaratively.
    # "follows" means it uses the same nixpkgs as above — avoids duplicates.
    # -------------------------------------------------------------------------
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------------------------------------------------------------------
    # nixos-hardware — Community hardware profiles
    # Provides pre-made configs for common laptops and desktops.
    # Saves a lot of work for things like AMD/Nvidia quirks.
    # -------------------------------------------------------------------------
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # -------------------------------------------------------------------------
    # agenix — Declarative secret management using age encryption
    #
    # Secrets are encrypted with age (using SSH public keys as recipients)
    # and stored in secrets/ inside the repo. At activation time, agenix
    # decrypts them using the host's SSH private key and places them at
    # their configured paths on disk.
    #
    # No plaintext secrets ever touch the repo — only the encrypted .age files.
    # -------------------------------------------------------------------------
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------------------------------------------------------------------
    # affinity-nix — Affinity v3 (Photo/Designer/Publisher) via Wine
    #
    # Affinity has no native Linux build. This flake wraps the free Windows
    # app in ElementalWarrior's patched Wine fork so it runs on NixOS.
    # The overlay and garnix cache are scoped to modules/system/graphical/affinity/
    # so headless servers never evaluate it.
    #
    # Do NOT add nixpkgs.follows here — the flake pins its own nixpkgs commit
    # for Wine build stability. Overriding it breaks the Wine build.
    # -------------------------------------------------------------------------
    affinity-nix.url = "github:mrshmllow/affinity-nix";

    # -------------------------------------------------------------------------
    # dms — DankMaterialShell
    #
    # Full Quickshell-based shell layer for Hyprland: bar, launcher,
    # notifications, OSD, sidebar, dynamic matugen theming, wallpaper
    # management, and dms-greeter login screen.
    #
    # nixpkgs.follows pins DMS and its bundled Quickshell to the same
    # Qt version as the rest of the system — prevents Qt version mismatch crashes.
    # -------------------------------------------------------------------------
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------------------------------------------------------------------
    # danksearch — Indexed filesystem search service
    #
    # Powers the file search feature in the DMS launcher (Spotlight-style).
    # Runs as a user systemd service, indexes configured paths, and exposes
    # a local REST API that DMS queries for file results.
    # -------------------------------------------------------------------------
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------------------------------------------------------------------
    # helium-browser — Nix flake for the Helium browser
    #
    # Helium is a privacy-focused Chromium-based browser with built-in ad/
    # tracker blocking, split-view, and !bang search shortcuts.
    # Not in nixpkgs — packaged via community flake (prebuilt binaries).
    # -------------------------------------------------------------------------
    helium-browser.url = "github:schembriaiden/helium-browser-nix-flake";

    # -------------------------------------------------------------------------
    # zen-browser — Nix flake for Zen Browser
    #
    # Zen is a Firefox-based browser with a focus on privacy and a minimal UI.
    # Not in nixpkgs — packaged via community flake (prebuilt binaries).
    # Enable per host: programs.zenBrowser.enable = true;
    # -------------------------------------------------------------------------
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------------------------------------------------------------------
    # noctalia — Noctalia shell (v5+), built from the upstream flake
    #
    # v5 is a full C++ rewrite of the Quickshell/QML v4 shell. Not yet in
    # nixpkgs. The upstream flake ships homeModules.default with a proper
    # programs.noctalia HM module (systemd service, settings TOML, etc.).
    #
    # nru updates the ref tag when a new release appears (scripts/noctalia-update.sh).
    # The sentinel comment below is the sed target — do not change its format.
    #
    # nixpkgs.follows ensures the noctalia binary is linked against the same
    # glibc/wayland/etc as the rest of the system.
    # -------------------------------------------------------------------------
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.0.0-beta.6"; # noctalia-version-nru
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  # ===========================================================================
  # OUTPUTS — What this flake produces
  #
  # The outputs function receives all inputs and returns your configurations.
  # `@inputs` captures the whole inputs set so we can pass it around easily.
  # ===========================================================================
  outputs = { self, nixpkgs, home-manager, nixos-hardware, agenix, ... } @ inputs:

    # -------------------------------------------------------------------------
    # let...in — Nix's way of defining local variables
    # We define helpers here to avoid repeating ourselves below.
    # -------------------------------------------------------------------------
    let
      # The system architecture all our machines use.
      # x86_64-linux covers all standard AMD and Intel 64-bit machines.
      system = "x86_64-linux";

      # A shortcut to the nixpkgs package set with our settings applied.
      pkgs = import nixpkgs {
        inherit system;
        config = {
          # Allows installation of proprietary software (Nvidia drivers,
          # Steam, etc). Required for gaming and some hardware support.
          allowUnfree = true;
        };
      };

      # -----------------------------------------------------------------------
      # mkHost — A helper function to build a NixOS host configuration
      #
      # Instead of repeating the same boilerplate for every host, we define
      # it once here. Each host just passes in what makes it unique.
      #
      # Arguments:
      #   hostname     — The machine's network name (e.g. "ThinkPad")
      #   hostConfig   — Path to the host's config file in hosts/
      #   user         — The primary user on this machine
      #   userConfig   — Path to the user's Home Manager config in users/
      #   wallpaperDir     — Wallpaper subfolder from ~/assets/Wallpapers/
      #                      Gets symlinked to ~/Pictures/Wallpapers
      #                      Options: "4k", "3440x1440", "PikaOS"
      #   hypridleProfile  — Which hypridle config to activate on this host.
      #                      Options: "desktop" (no suspend), "laptop" (suspend)
      #                      Default: "laptop" (safe fallback)
      #   extraModules — Any additional modules specific to this host
      # -----------------------------------------------------------------------
      mkHost = {
        hostname,
        hostConfig,
        user,
        userConfig       ? null,
        wallpaperDir     ? "4k",
        hypridleProfile  ? "laptop",
        extraModules     ? []
      }:
        nixpkgs.lib.nixosSystem {
          # Pass inputs down so any module can access them if needed
          specialArgs = { inherit inputs; };
          modules = [
            # Set the host platform — replaces the deprecated `system` argument
            { nixpkgs.hostPlatform.system = system; }

            # The host's specific hardware and role configuration
            hostConfig

            # agenix — secret management via age encryption.
            # Provides the age.secrets.* options used throughout host configs.
            agenix.nixosModules.default

            # Option-gated hardware modules — imported for every host but
            # dormant until enabled, e.g. hardware.openrgb.enable = true;
            # Hosts toggle these with flags instead of imports.
            ./modules/hardware/openrgb/default.nix
            ./modules/hardware/peripherals/lemokey-keychron/default.nix

            # Home Manager as a NixOS module — this means Home Manager
            # runs as part of nixos-rebuild, keeping everything in sync
            home-manager.nixosModules.home-manager

            # Pin claude-code to 2.1.86 — 2.1.88 was pushed to nixpkgs-unstable but
            # removed from npm (404). Remove this overlay once nixpkgs carries a
            # version that downloads successfully.
            {
              nixpkgs.overlays = [
                (final: prev: {
                  claude-code  = prev.callPackage ./pkgs/claude-code/package.nix {};
                  opencode     = prev.callPackage ./pkgs/opencode/package.nix {};
                  ponytrail    = prev.callPackage ./pkgs/ponytrail/package.nix {};
                  # proton-ge-custom and goverlay overlays live in modules/gaming/default.nix
                  # so they are only fetched on hosts that import the gaming module.
                  ant-dark-kde                  = prev.callPackage ./pkgs/ant-dark-kde/package.nix {};
                  breeze-chameleon-dark-icons   = prev.callPackage ./pkgs/breeze-chameleon-dark-icons/package.nix {};
                  # openldap 2.6.13 test017-syncreplication-refresh is flaky
                  # (timing-sensitive); skip tests to unblock the build.
                  openldap    = prev.openldap.overrideAttrs (_: { doCheck = false; });
                  # poetry 2.4.1 install-check tests fail on python 3.14 — upstream
                  # string-formatting assertions don't account for py3.14 output changes.
                  # pkgs.poetry/package.nix uses a self-contained private python3 scope;
                  # all overlay approaches that target doInstallCheck/python3.pkgs are
                  # swallowed by newPackageOverrides re-calling callPackage ./unwrapped.nix.
                  # Removing nativeCheckInputs from the final drv changes the build inputs
                  # directly, producing a new drv that skips pytestCheckHook entirely.
                  poetry = prev.poetry.overridePythonAttrs (_: {
                    nativeCheckInputs = [ ];
                  });
                })

              ];
            }

            # Home Manager settings that apply to all hosts
            {
              home-manager = {
                # Use the same nixpkgs as the system — avoids conflicts
                useGlobalPkgs   = true;
                # Allow each user's HM config to install packages
                useUserPackages = true;
                # Pass inputs AND wallpaperDir into Home Manager modules.
                # wallpaperDir tells the user's home.nix which wallpaper
                # folder to symlink into ~/Pictures/Wallpapers.
                # Servers skip this entirely since userConfig is null.
                extraSpecialArgs = { inherit inputs wallpaperDir hypridleProfile; };
                # Wire up the user's Home Manager config if one exists.
                # Servers won't have a userConfig so we skip it.
                users = nixpkgs.lib.optionalAttrs (userConfig != null) {
                  ${user} = userConfig;
                };
              };
            }
          # Merge in any extra modules passed for this specific host
          ] ++ extraModules;
        };

    in {

      # =======================================================================
      # nixosConfigurations — Your actual host definitions
      #
      # Each entry here becomes a buildable NixOS system.
      # To build and switch: sudo nixos-rebuild switch --flake .#ThinkPad
      # =======================================================================
      nixosConfigurations = {

        # ---------------------------------------------------------------------
        # YOUR MACHINES (linuxury)
        #
        # ThinkPad  → 4k wallpapers (standard laptop display)
        # Ryzen5900x → 3440x1440 wallpapers (ultrawide monitor)
        # ---------------------------------------------------------------------

        ThinkPad = mkHost {
          hostname        = "ThinkPad";
          hostConfig      = ./hosts/ThinkPad/default.nix;
          user            = "linuxury";
          userConfig      = ./users/linuxury/home.nix;
          wallpaperDir    = "4k";
          hypridleProfile = "laptop";
          extraModules = [
            # nixos-hardware profile for ThinkPad AMD laptops
            # Handles power management, thermal, etc automatically
            nixos-hardware.nixosModules.lenovo-thinkpad
          ];
        };

        Ryzen5900x = mkHost {
          hostname        = "Ryzen5900x";
          hostConfig      = ./hosts/Ryzen5900x/default.nix;
          user            = "linuxury";
          userConfig      = ./users/linuxury/home.nix;
          wallpaperDir    = "3440x1440";  # Ultrawide monitor
          hypridleProfile = "desktop";
        };

        # ---------------------------------------------------------------------
        # WIFE'S MACHINES (babylinux)
        #
        # Both machines → 4k wallpapers
        # ---------------------------------------------------------------------

        Ryzen5800x = mkHost {
          hostname     = "Ryzen5800x";
          hostConfig   = ./hosts/Ryzen5800x/default.nix;
          user         = "babylinux";
          userConfig   = ./users/babylinux/home.nix;
          wallpaperDir = "4k";
        };

        Asus-A15 = mkHost {
          hostname     = "Asus-A15";
          hostConfig   = ./hosts/Asus-A15/default.nix;
          user         = "babylinux";
          userConfig   = ./users/babylinux/home.nix;
          wallpaperDir = "4k";
          extraModules = [
            # Asus A15 has hybrid AMD + Nvidia graphics
            # This hardware module handles the tricky parts automatically
            nixos-hardware.nixosModules.asus-battery
          ];
        };

        # ---------------------------------------------------------------------
        # KID'S MACHINES (alex)
        #
        # Both machines → PikaOS wallpapers (kid friendly)
        # ---------------------------------------------------------------------

        Alex-Desktop = mkHost {
          hostname     = "Alex-Desktop";
          hostConfig   = ./hosts/Alex-Desktop/default.nix;
          user         = "alex";
          userConfig   = ./users/alex/home.nix;
          wallpaperDir = "PikaOS";
        };

        Alex-Laptop = mkHost {
          hostname     = "Alex-Laptop";
          hostConfig   = ./hosts/Alex-Laptop/default.nix;
          user         = "alex";
          userConfig   = ./users/alex/home.nix;
          wallpaperDir = "PikaOS";
        };

        # ---------------------------------------------------------------------
        # HEADLESS SERVERS
        #
        # No Home Manager — managed via SSH by linuxury.
        # wallpaperDir defaults to "4k" but is unused since
        # userConfig is null and Home Manager is skipped entirely.
        # ---------------------------------------------------------------------

        MinisForum = mkHost {
          hostname   = "MinisForum";
          hostConfig = ./hosts/MinisForum/default.nix;
          user       = "linuxury";
          # No userConfig — headless servers don't need Home Manager
        };

        Radxa-X4 = mkHost {
          hostname   = "Radxa-X4";
          hostConfig = ./hosts/Radxa-X4/default.nix;
          user       = "linuxury";
        };

        Media-Server = mkHost {
          hostname   = "Media-Server";
          hostConfig = ./hosts/Media-Server/default.nix;
          user       = "linuxury";
        };

      };
    };
}
