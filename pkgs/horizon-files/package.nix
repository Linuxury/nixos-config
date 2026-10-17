{
  lib,
  stdenv,
  src,
  meson,
  ninja,
  pkg-config,
  wayland-scanner,
  makeWrapper,
  wayland,
  wayland-protocols,
  cairo,
  pango,
  libxkbcommon,
  glib,
  libwebp,
  libjpeg,
  openssl,
  sdbus-cpp_2,
  fontconfig,
  libarchive,
  poppler,
  librsvg,
  liburing,
  zlib,
  xz,
  libsoup_3,
  json-glib,
  libsecret,
  gtk4,
  libadwaita,
  gnome-online-accounts,
  ffmpegthumbnailer,
  systemd,
  # true = keep the org.freedesktop.FileManager1 D-Bus service (browsers'
  # "Show in folder"). Only when Horizon is the default file manager.
  withFileManager1 ? false,
}:
# Horizon File Manager (https://github.com/Event-Horizon-desktop-environment/Horizon-File-Manager)
# — Wayland-native file manager. `src` is the horizon-files flake input
# (default branch + submodules, bumped by nru like noctalia/umbriel).
#
# Upstream assumes an FHS /usr install; the patches below adapt it:
# - its meson.build compiles ffmpegthumbnailer with cmake at configure time and
#   bakes that build-dir path in; point it at nixpkgs' ffmpegthumbnailer instead
# - "Open with" reads the system mimeinfo.cache from /usr/share/applications
# - UI assets are looked up via EH_ASSETS_DIR (set by the wrapper)
stdenv.mkDerivation {
  pname = "horizon-files";
  version = "0.1.0-unstable-${lib.substring 0 8 (src.lastModifiedDate or "19700101")}";
  inherit src;

  nativeBuildInputs = [ meson ninja pkg-config wayland-scanner makeWrapper ];

  buildInputs = [
    wayland wayland-protocols cairo pango libxkbcommon glib libwebp libjpeg openssl
    sdbus-cpp_2 systemd fontconfig libarchive poppler librsvg liburing zlib xz
    libsoup_3 json-glib libsecret                # Drive + keyring
    gtk4 libadwaita gnome-online-accounts        # horizon-goa-signin helper
  ];

  postPatch = ''
    # Replace the "Build ffmpegthumbnailer from source" block (comment → endif).
    sed -i '/Build ffmpegthumbnailer from source/,/^endif/c\
    cpp_args += ['"'"'-DFFMPEGTHUMBNAILER_BIN="${ffmpegthumbnailer}/bin/ffmpegthumbnailer"'"'"']' meson.build
    grep -q 'FFMPEGTHUMBNAILER_BIN="${ffmpegthumbnailer}' meson.build

    substituteInPlace src/app/file_browser/features/open_with/open_with.cpp \
      --replace-fail /usr/share/applications/ /run/current-system/sw/share/applications/
  '';

  # Upstream builds with -Werror; nixpkgs' fortify hardening adds warnings
  # (e.g. unused chdir() result) that upstream's distro builds don't see.
  env.NIX_CFLAGS_COMPILE = "-Wno-error";

  # Upstream's test targets are benchmarks / stress scripts.
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/horizon-files \
      --set-default EH_ASSETS_DIR $out/share/event-horizon/assets \
      --prefix PATH : $out/bin
  '' + lib.optionalString (!withFileManager1) ''
    # Alternate file manager: don't compete with Nautilus for
    # org.freedesktop.FileManager1 (browsers' "Show in folder").
    rm -f $out/share/dbus-1/services/org.freedesktop.FileManager1.service
  '';

  meta = {
    description = "Wayland-native file manager from the Event Horizon desktop";
    homepage = "https://github.com/Event-Horizon-desktop-environment/Horizon-File-Manager";
    license = lib.licenses.unfree; # no license file upstream (all rights reserved)
    platforms = lib.platforms.linux;
    mainProgram = "horizon-files";
  };
}
