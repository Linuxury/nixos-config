# ===========================================================================
# modules/system/graphical/firefox/default.nix — Firefox
#
# Installs Firefox with no managed policies — pure out-of-box experience.
# Imported per-host via the host imports list.
# ===========================================================================

{ ... }:

{
  programs.firefox.enable = true;

  # gfx.wayland.hdr — Linux/Wayland HDR video playback (experimental, uses the
  # color-management-v1 protocol Hyprland now speaks). Status = "default" sets
  # the default but leaves it user-changeable in about:config, keeping this
  # module's "no managed policies" intent.
  programs.firefox.policies.Preferences = {
    "gfx.wayland.hdr" = {
      Value  = true;
      Status = "default";
    };
  };
}
