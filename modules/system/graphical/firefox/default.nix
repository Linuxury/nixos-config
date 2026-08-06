# ===========================================================================
# modules/system/graphical/firefox/default.nix — Firefox
#
# Installs Firefox with no managed policies — pure out-of-box experience.
# Imported per-host via the host imports list.
# ===========================================================================

{ ... }:

{
  programs.firefox.enable = true;

  # gfx.color_management.hdr / .force_enabled — tried for Linux/Wayland HDR
  # video playback, reverted. Confirmed live: HDR did engage (Hyprland
  # switched the monitor to HDR mode), but video rendered with a blown-out
  # red tint — matches Mozilla's own tracked regressions for this feature
  # (bugzilla 1642854 "HDR video support for Linux" and related Wayland
  # color-management reports: "HDR video on YouTube appears blown out
  # compared to properly configured video players"). This is a genuine
  # upstream Gecko bug, not fixable from config — revisit once Mozilla
  # lands a fix. Broken red-tinted HDR is worse than normal SDR, so left off.
}
