# ===========================================================================
# modules/system/graphical/firefox/default.nix — Firefox
#
# Installs Firefox with no managed policies — pure out-of-box experience.
# Imported per-host via the host imports list.
# ===========================================================================

{ ... }:

{
  programs.firefox.enable = true;

  # gfx.color_management.hdr — Linux/Wayland HDR video playback (experimental,
  # uses the color-management-v1 protocol Hyprland now speaks). Confirmed via
  # `strings libxul.so` that this is the real pref this build recognizes —
  # gfx.wayland.hdr (an earlier guess from a secondary source) doesn't exist
  # in the binary at all and was a silent no-op. Status = "default" sets the
  # default but leaves it user-changeable in about:config, keeping this
  # module's "no managed policies" intent.
  #
  # If HDR still doesn't trigger with this pref, also try
  # gfx.color_management.hdr.force_enabled — bypasses whatever
  # capability/heuristic check gates the plain pref.
  programs.firefox.policies.Preferences = {
    "gfx.color_management.hdr" = {
      Value  = true;
      Status = "default";
    };
  };
}
