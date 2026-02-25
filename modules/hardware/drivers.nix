# ===========================================================================
# modules/hardware/drivers.nix — GPU and CPU driver configuration
#
# This module uses a simple option system. Each host declares which
# hardware type it has, and this module enables the right drivers.
#
# In your host config file you'll set ONE of these:
#
#   hardware.gpu = "amd";          # AMD CPU + AMD GPU (most of your machines)
#   hardware.gpu = "intel";        # Intel CPU + Intel integrated graphics
#   hardware.gpu = "nvidia-hybrid"; # AMD CPU + Nvidia GPU (wife's Asus A15)
#
# That's it. The rest is handled here automatically.
# ===========================================================================

{ config, pkgs, lib, ... }:

# lib.mkOption lets us define a custom option that host configs can set.
# Think of it like a variable that this module reads to decide what to enable.
{
  options.hardware.gpu = lib.mkOption {
    # The type must be one of these exact strings
    type = lib.types.enum [ "amd" "intel" "nvidia-hybrid" ];
    # No default — every host MUST declare its GPU type or it will error.
    # This prevents silent misconfiguration.
    description = "GPU type for this host. Must be set in every host config.";
  };

  # config is where the actual settings live.
  # lib.mkMerge combines multiple conditional blocks cleanly.
  config = lib.mkMerge [

    # =========================================================================
    # AMD — Used by your desktops/laptops, wife's desktop, kid's machines
    #
    # amdgpu is the open source AMD driver. It's built into the Linux kernel
    # and supports Vulkan, OpenGL, and hardware video decoding out of the box.
    # =========================================================================
    (lib.mkIf (config.hardware.gpu == "amd") {
      # Load the amdgpu kernel module early in the boot process.
      # "early" loading means it's available before the filesystem mounts,
      # which prevents a flash of black screen or framebuffer glitch on boot.
      boot.initrd.kernelModules = [ "amdgpu" ];

      services.xserver.videoDrivers = [ "amdgpu" ];

      hardware = {
        # Enable general OpenGL/Vulkan support
        graphics = {
          enable = true;
          # 32-bit support is required for Steam and many games
          enable32Bit = true;
          # Extra packages for hardware video decoding (AMD Video Codec Engine)
          # This offloads video playback to the GPU instead of the CPU
          extraPackages = with pkgs; [
            amdvlk          # AMD's official Vulkan driver (alternative to radv)
            rocmPackages.clr # OpenCL support for GPU compute
          ];
          # 32-bit versions of the above for Steam compatibility
          extraPackages32 = with pkgs; [
            driversi686Linux.amdvlk
          ];
        };

        # AMD-specific CPU microcode updates.
        # Microcode patches fix CPU bugs without needing a BIOS update.
        cpu.amd.updateMicrocode = true;
      };
    })

    # =========================================================================
    # INTEL — Used by MinisForum UN1250 and Radxa X4 (headless servers)
    #
    # Intel integrated graphics use the i915 kernel driver.
    # For headless servers this mostly just enables the correct kernel module
    # so the system boots cleanly without GPU errors in the logs.
    # =========================================================================
    (lib.mkIf (config.hardware.gpu == "intel") {
      boot.initrd.kernelModules = [ "i915" ];

      services.xserver.videoDrivers = [ "intel" ];

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
          # Intel media driver for hardware video decoding (VA-API)
          extraPackages = with pkgs; [
            intel-media-driver  # For newer Intel (Broadwell and later, covers i5-1250P)
            intel-vaapi-driver  # Older fallback driver
            libvdpau-va-gl      # VDPAU over VA-API bridge (for some video players)
          ];
        };

        # Intel CPU microcode updates
        cpu.intel.updateMicrocode = true;
      };
    })

    # =========================================================================
    # NVIDIA HYBRID — Used by wife's Asus A15
    #
    # Hybrid graphics means there are TWO GPUs:
    #   - The AMD integrated GPU (always on, handles the display output)
    #   - The Nvidia discrete GPU (more powerful, used for demanding tasks)
    #
    # PRIME offloading lets the system use the Nvidia GPU on demand
    # (e.g., for a game) while the AMD iGPU handles everything else.
    # This saves battery compared to keeping Nvidia always on.
    # =========================================================================
    (lib.mkIf (config.hardware.gpu == "nvidia-hybrid") {
      # Load both GPU drivers
      boot.initrd.kernelModules = [ "amdgpu" ];

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };

        nvidia = {
          # Use the stable Nvidia driver package.
          # modesetting is required for PRIME to work correctly.
          modesetting.enable = true;

          # PRIME offloading — Nvidia GPU activates only when asked.
          # Apps can request the Nvidia GPU by running with:
          #   nvidia-offload <application>
          # Everything else uses the AMD iGPU automatically.
          prime = {
            offload = {
              enable = true;
              enableOffloadCmd = true; # Adds the `nvidia-offload` helper command
            };
            # amdgpuBusId and nvidiaBusId are machine-specific.
            # They must be set in the host config (e.g. hosts/Asus-A15/default.nix).
            # Setting them here would conflict with the host-level definition.
          };

          # Power management helps with suspend/resume on hybrid systems
          powerManagement = {
            enable = true;
            finegrained = true; # Allows Nvidia GPU to fully power down when idle
          };

          # Open source Nvidia kernel module (available since driver 515+)
          # More stable on newer kernels than the fully proprietary module
          open = true;
        };

        # AMD microcode for the CPU side
        cpu.amd.updateMicrocode = true;
      };
    })

  ]; # end mkMerge
}
