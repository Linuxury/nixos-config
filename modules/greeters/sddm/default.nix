# ===========================================================================
# modules/greeters/sddm/default.nix — SDDM + hypr-sddm theme
#
# Provides a polished GUI login screen that works on any GPU without cage.
#
# Wayland mode, default compositor: weston (lightweight, no KDE required).
# KDE hosts override the compositor in desktops/kde/default.nix via mkForce.
#
# Import this module in any DE module that needs a login screen:
#   imports = [ ../../greeters/sddm/default.nix ];
#
# What this module owns:
#   - SDDM enable + Wayland mode (weston compositor by default)
#   - hypr-sddm theme (minimal blur, hyprlock-inspired aesthetic)
#   - Wallpaper sync dir (/var/lib/sddm/wallpaper/) for live wallpaper updates
#   - GNOME Keyring unlock via SDDM PAM service
#   - sddm user video/input groups (needed for greeter GPU access)
#   - /run/user/175 tmpfiles entry (SDDM runtime dir for the greeter session)
#
# What each DE module still owns:
#   - Registering its own session package (services.displayManager.sessionPackages)
#   - Any compositor-specific SDDM overrides (KDE: CompositorCommand, GreeterEnvironment)
#   - Copying the current wallpaper to /var/lib/sddm/wallpaper/background.jpg
#     (handled by modules/compositors/hyprland/matugen/default.nix)
#   - services.gnome.gnome-keyring.enable (session-level concern, not greeter)
# ===========================================================================

{ pkgs, lib, ... }:

let
  # ---------------------------------------------------------------------------
  # Patch script for Main.qml — extracted to writeText so it lives in its own
  # Nix string (2-space minimum indent → correctly stripped by Nix) rather than
  # inline in installPhase (where zero-indented Python lines would force Nix to
  # strip zero spaces, breaking the CONF heredoc's end-marker recognition).
  # ---------------------------------------------------------------------------
  mainQmlPatch = pkgs.writeText "hypr-sddm-avatar-patch.py" ''
    import sys

    path = sys.argv[1]
    with open(path) as f:
        content = f.read()

    # Canvas.drawImage(img) silently fails in Qt 6 when img has visible:false —
    # hidden items are skipped by the scene graph so their texture is never
    # uploaded to the GPU.  Changing to opacity:0 keeps the item visible (texture
    # resident) while remaining invisible to the user.  The Canvas circular crop
    # then works correctly and the letter-circle fallback shows if no photo found.
    old = "smooth: true; visible: false"
    new = "smooth: true; opacity: 0"

    if old not in content:
        print("WARN: avatar Image property not found — skipping patch")
    else:
        content = content.replace(old, new, 1)
        with open(path, "w") as f:
            f.write(content)
        print("Patched Main.qml: avatar Image visible:false -> opacity:0")
  '';

  # ---------------------------------------------------------------------------
  # hypr-sddm — minimal SDDM theme inspired by hyprlock's design philosophy.
  # Gaussian-blurred wallpaper, dark translucent card, stacked clock, no chrome.
  #
  # theme.conf bakes in an absolute background path (/var/lib/sddm-wallpaper/)
  # rather than the store-relative default. The QML color extractor reads the
  # wallpaper at runtime and derives the full palette automatically — no manual
  # color config needed. hypr-matugen writes the wallpaper there on every change.
  # ---------------------------------------------------------------------------
  hypr-sddm = pkgs.stdenv.mkDerivation {
    pname   = "hypr-sddm";
    version = "unstable-2026-05-17";
    src = pkgs.fetchFromGitHub {
      owner  = "ADIOR-enigma";
      repo   = "hypr-sddm";
      rev    = "52fd4a538fabea2331d9b9f956c2497ff5f9102c";
      sha256 = "0mi517w339hrdq79n2p7arb2kf6l85bv57kp542q9cykcagw6p4a";
    };
    dontBuild        = true;
    dontConfigure    = true;
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase  = ''
      runHook preInstall
      dest="$out/share/sddm/themes/hypr-sddm"
      mkdir -p "$dest"
      cp -r . "$dest/"

      # Replace theme.conf: point background at the mutable sync path so
      # every wallpaper change on the desktop is reflected at next login.
      # Colors are auto-derived from the wallpaper by the QML canvas extractor.
      cat > "$dest/theme.conf" << 'CONF'
      [General]
      background=/var/lib/sddm-wallpaper/background.jpg
      primaryColor=#E3E3DC
      accentColor=#A9C78F
      backgroundColor=#1A1C18
      textColor=#E3E3DC
      fontFamily=Sans
      fontSize=12
      CONF

      # Patch Main.qml: replace Canvas+hidden-Image avatar with Rectangle+clip.
      # See mainQmlPatch above for the full explanation.
      python3 ${mainQmlPatch} "$dest/Main.qml"

      runHook postInstall
    '';
  };
in

{
  services.displayManager.sddm = {
    enable = true;
    # Wayland mode — uses weston by default (safe on any GPU, no kwin needed).
    # KDE overrides the compositor command in desktops/kde/default.nix via mkForce.
    wayland.enable = true;
    # Full store path avoids having to add hypr-sddm to systemPackages.
    theme = "${hypr-sddm}/share/sddm/themes/hypr-sddm";
    # hypr-sddm's Main.qml imports QtQuick.VirtualKeyboard — not bundled with
    # SDDM by default. extraPackages injects Qt packages into the greeter's env.
    extraPackages = [ pkgs.qt6Packages.qtvirtualkeyboard ];
  };

  # NixOS only sets [Theme] CursorTheme when cfg.theme == "" (default SDDM theme).
  # With a custom theme (catppuccin-sddm), it's omitted — and SDDM shows no cursor.
  # Set it explicitly here so the greeter always has a cursor regardless of theme.
  # Compositor modules override these to their preferred theme (e.g. BreezeX-Light).
  services.displayManager.sddm.settings.Theme = {
    CursorTheme = lib.mkDefault "Adwaita";
    CursorSize  = lib.mkDefault "24";
  };

  # SDDM authenticates via its own PAM service — "greetd" is not involved.
  # This unlocks the GNOME Keyring at login so apps (Proton Pass, SSH agent,
  # etc.) can access it without prompting for a password after the desktop loads.
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;  # TTY login fallback

  # sddm-greeter-qt6 must run as a pure Wayland client inside weston.
  #
  # GreeterEnvironment is comma-separated and only reaches the Qt greeter process
  # (NOT weston — weston inherits SDDM's process env, see systemd.services.sddm below).
  #
  # QT_QPA_PLATFORM=wayland              — forces Qt6 to use the Wayland QPA plugin.
  # QT_QPA_PLATFORMTHEME=                — CRITICAL: disables the gtk3 platform theme plugin.
  #                                         Without this, Qt loads gtk3 → gtk_init() → tries
  #                                         X11 → no display → exit(1) → greeter crashes.
  # QT_WAYLAND_SHELL_INTEGRATION=layer-shell — CRITICAL: makes the greeter surface use the
  #                                         wlr-layer-shell protocol instead of xdg-shell.
  #                                         Without this, the greeter surface doesn't receive
  #                                         wl_pointer focus in Weston kiosk mode, so Qt never
  #                                         calls wl_pointer.set_cursor → cursor invisible.
  #                                         This matches what NixOS's upstream SDDM module sets.
  # XCURSOR_THEME                        — cursor theme name for libwayland-cursor.
  # XCURSOR_SIZE                         — cursor size in pixels.
  # XCURSOR_PATH                         — libXcursor search path for cursor themes.
  # XDG_DATA_DIRS                        — Qt6's cursor plugin also searches here for themes.
  #
  # Compositor modules override this via a plain assignment (priority 100 > mkDefault 1000).
  # KDE overrides it in desktops/kde/default.nix.
  services.displayManager.sddm.settings.General.GreeterEnvironment =
    lib.mkDefault "QT_QPA_PLATFORM=wayland,QT_QPA_PLATFORMTHEME=,XCURSOR_THEME=Adwaita,XCURSOR_SIZE=24,XCURSOR_PATH=/run/current-system/sw/share/icons,XDG_DATA_DIRS=/run/current-system/sw/share";

  # Weston (the greeter compositor) is launched by SDDM and inherits SDDM's own
  # process environment — NOT GreeterEnvironment. Weston reads XCURSOR_THEME and
  # XCURSOR_PATH from its environment to render the cursor for all Wayland clients.
  # Setting them here (on the sddm systemd unit) makes them available to Weston.
  #
  # Compositor modules (e.g. hyprland) override these to their preferred theme.
  # Adwaita is the safe fallback: always available via adwaita-icon-theme below.
  systemd.services.sddm.environment = {
    XCURSOR_THEME = lib.mkDefault "Adwaita";
    XCURSOR_SIZE  = lib.mkDefault "24";
    XCURSOR_PATH  = lib.mkDefault "/run/current-system/sw/share/icons";
  };

  # Adwaita cursor — fallback theme, always available system-wide.
  environment.systemPackages = [ pkgs.adwaita-icon-theme ];

  # Prevent SDDM from being restarted mid-session during nixos-rebuild switch.
  # nixpkgs is rolling — Qt6/KWin change often, which would otherwise kick the
  # active Hyprland session to the login screen on every rebuild.
  # SDDM changes take effect on the next reboot or manual service restart.
  systemd.services.display-manager.restartIfChanged = false;

  # seatd manages seat (GPU/input device) access for Wayland compositors.
  # With seatd running, libseat in weston and MangoWC/kwin uses seatd's backend
  # instead of logind's. seatd handles DRM master handoff between compositors
  # cleanly (greeter exits → user compositor takes over) without the VT race
  # condition that occurs with the logind backend.
  # The 'seat' group is required for any user/process that needs seat access.
  services.seatd.enable = true;
  users.users.sddm.extraGroups = [ "video" "input" "seat" ];

  # SDDM sets XDG_RUNTIME_DIR=/run/user/175 for the sddm user (uid 175 on NixOS)
  # but systemd-logind never creates it for greeter sessions — create it manually.
  #
  # ~/.icons and ~/.local/share/icons: libXcursor (used by libwayland-cursor and
  # Qt6's cursor plugin) searches these dirs by default for cursor themes, before
  # any XCURSOR_PATH lookup. Symlinking the theme here ensures cursor files are
  # found even if XCURSOR_PATH handling differs between library versions.
  # Compositor modules add their own theme symlink (e.g. BreezeX-Light).
  systemd.tmpfiles.rules = [
    "d /run/user/175                            0700 sddm sddm -"
    "d /var/lib/sddm/.icons                     0755 sddm sddm -"
    # Declare each intermediate dir explicitly so systemd-tmpfiles doesn't hit
    # "unsafe path transition" errors (happens when a parent is owned by root).
    "d /var/lib/sddm/.local                     0755 sddm sddm -"
    "d /var/lib/sddm/.local/share               0755 sddm sddm -"
    "d /var/lib/sddm/.local/share/icons         0755 sddm sddm -"
    "L /var/lib/sddm/.icons/Adwaita             - - - - /run/current-system/sw/share/icons/Adwaita"
    "L /var/lib/sddm/.local/share/icons/Adwaita - - - - /run/current-system/sw/share/icons/Adwaita"

  ];

  # Wallpaper sync target — lives at /var/lib/sddm-wallpaper/ (NOT inside
  # /var/lib/sddm/ which is 0700 sddm:sddm and not traversable by regular users).
  # 0775 root:users lets any logged-in user write the file; sddm reads as "other".
  # activationScripts runs on every nixos-rebuild switch (unlike tmpfiles which
  # only runs at boot), so the dir exists immediately after the first switch.
  system.activationScripts.sddm-wallpaper-dir = ''
    mkdir -p /var/lib/sddm-wallpaper
    chown root:users /var/lib/sddm-wallpaper
    chmod 0775 /var/lib/sddm-wallpaper
  '';
}
