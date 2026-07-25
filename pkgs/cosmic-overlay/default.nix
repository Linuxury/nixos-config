# ===========================================================================
# pkgs/cosmic-overlay/default.nix — COSMIC Desktop version overlay
#
# Tracks pop-os/cosmic-epoch releases directly, bypassing nixpkgs packaging
# delays. nru calls scripts/cosmic-update.sh whenever a new epoch tag appears.
# That script:
#   1. Fetches all src hashes in parallel (nix store prefetch-file)
#   2. Resolves all cargo vendor hashes in parallel (fake-hash trick via
#      nix build --impure --expr on fetchCargoVendor)
#   3. Detects new components in pop-os/cosmic-epoch and auto-adds them
#      if they already exist in nixpkgs, warns otherwise
#
# Sentinel comments are sed targets used by scripts/cosmic-update.sh.
# Do not move them to a different line from their hash value.
#
#   # cosmic-version-nru     — the shared version string
#   # cosmic-src-<pkg>       — src fetchFromGitHub hash for <pkg>
#   # cosmic-cargo-<pkg>     — cargo vendor hash for <pkg> (Rust only)
# ===========================================================================

final: prev:
let
  cosmicVersion = "1.4.0"; # cosmic-version-nru

  # Fetch a COSMIC component source at the current epoch version.
  fetchCosmic = repo: hash: final.fetchFromGitHub {
    owner = "pop-os";
    inherit repo;
    tag  = "epoch-${cosmicVersion}";
    inherit hash;
  };

  # Override a Rust COSMIC package — bumps version, src, and cargo vendor hash.
  mkCosmic = pkg: repo: srcHash: cargoHash:
    let _src = fetchCosmic repo srcHash;
    in prev.${pkg}.overrideAttrs (old: {
      version   = cosmicVersion;
      src       = _src;
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (old) pname;
        version = cosmicVersion;
        src     = _src;
        hash    = cargoHash;
      };
    });

  # Override a non-Rust COSMIC package (icons, wallpapers, sound-theme).
  # These are asset/resource packages with no Rust build step.
  mkCosmicAsset = pkg: repo: srcHash:
    prev.${pkg}.overrideAttrs (_: {
      version = cosmicVersion;
      src     = fetchCosmic repo srcHash;
    });

in
{

  # ── Rust packages ─────────────────────────────────────────────────────────
  # Two sentinel lines per package:
  #   "sha256-..." # cosmic-src-<pkg>       ← src hash
  #   "sha256-..."; # cosmic-cargo-<pkg>    ← cargo vendor hash

  cosmic-app-library = mkCosmic "cosmic-app-library" "cosmic-applibrary"
    "sha256-ol0WH3L7Vh1ao5rQw0svegWna4Yn8qsq4+uwELLPPN0=" # cosmic-src-cosmic-app-library
    "sha256-Lq1Gs1/dcIxfWM4jNIH2qGu94HCC+JKxFdUTb/MDHzg="; # cosmic-cargo-cosmic-app-library

  cosmic-applets =
    let _src = fetchCosmic "cosmic-applets"
      "sha256-ZtbU3bDpBiC4cDGBiKKY//zBjNqrLYKhR9rIwVZ9aGY="; # cosmic-src-cosmic-applets
    in prev.cosmic-applets.overrideAttrs (old: {
      version   = cosmicVersion;
      src       = _src;
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (old) pname;
        version = cosmicVersion;
        src     = _src;
        hash    = "sha256-xgpsIynrVcN62IQ++ABZqqbP0ak86eQYTc1SCSxy2l4="; # cosmic-cargo-cosmic-applets
      };
      # dedup-cosmic-settings-daemon.patch targets old Cargo.lock; 1.4.0 fixes this upstream
      patches = [];
    });

  cosmic-bg = mkCosmic "cosmic-bg" "cosmic-bg"
    "sha256-yPUbkcQmJGOcKkpi3pfHHW8ggw7juTW3GHD8l+kDI9w=" # cosmic-src-cosmic-bg
    "sha256-wU9McdejpTFNJd2VTrMREzdW4WIw0p5GTuhynt/vVro="; # cosmic-cargo-cosmic-bg

  cosmic-comp = mkCosmic "cosmic-comp" "cosmic-comp"
    "sha256-r1VllV3BLXYJPt8XMk9mtaLaWEr1noyUnS45wgczzkM=" # cosmic-src-cosmic-comp
    "sha256-lrOeTj/KdO+BYIH1gKEByUfpuf53XQ5iKAsQ0peYExw="; # cosmic-cargo-cosmic-comp

  cosmic-edit = mkCosmic "cosmic-edit" "cosmic-edit"
    "sha256-cONn5AksnZeqFKDEb5oMWspWn62rRqzeBKZtnvEpbng=" # cosmic-src-cosmic-edit
    "sha256-aIPvetY9ezCv7RgoyC8x7O8mTrnUqth+YuSYHWiPQVU="; # cosmic-cargo-cosmic-edit

  cosmic-files = mkCosmic "cosmic-files" "cosmic-files"
    "sha256-MG3ihfd9/QBr/ayEcVxdPqKehcZAJEy+o4Hv2d+ofPM=" # cosmic-src-cosmic-files
    "sha256-DX6RzB7VHhdA+Hfi6llwMVGUaHj36viGAYkmOSiAtrU="; # cosmic-cargo-cosmic-files

  cosmic-greeter = mkCosmic "cosmic-greeter" "cosmic-greeter"
    "sha256-GOHuuMVUd9LPRvmEYHuAxSoMz59/3uuAMjiRzpoUX/w=" # cosmic-src-cosmic-greeter
    "sha256-5A+7sgZqJcXjK51i5thAm9LK1SrW9ly8NHyf3IZfWQA="; # cosmic-cargo-cosmic-greeter

  cosmic-idle = mkCosmic "cosmic-idle" "cosmic-idle"
    "sha256-0tcrOfVT5b57ev3b5F2U78F2QPGFwp94bqFVNyKH0Yk=" # cosmic-src-cosmic-idle
    "sha256-wAjFC6qAC3nllbnZf0KVaZTEztNYo6GTvwcp5FYmXLw="; # cosmic-cargo-cosmic-idle

  cosmic-initial-setup = mkCosmic "cosmic-initial-setup" "cosmic-initial-setup"
    "sha256-bTy/e60nInZCKulsNm9QmgeT6eSLRRCv0D+yP3oTQ1U=" # cosmic-src-cosmic-initial-setup
    "sha256-pQmWdt53G/JJN37jTkGBYb1lfOT6aiwwNXKZGA9Es7w="; # cosmic-cargo-cosmic-initial-setup

  cosmic-launcher = mkCosmic "cosmic-launcher" "cosmic-launcher"
    "sha256-A/2n/kGDbt2+OKRKdX2JAfjnbjxqIfcjg0QT1ctCKXA=" # cosmic-src-cosmic-launcher
    "sha256-TCgQ1WMvyqa+YdpUWDPaWzbkQDNX1YEIxqx2M+ENKH0="; # cosmic-cargo-cosmic-launcher

  cosmic-monitor = mkCosmic "cosmic-monitor" "cosmic-monitor"
    "sha256-EIxdQo80yAjb2rgEsbTPiLuPcyRoJCPe6uDqPeaSCHQ=" # cosmic-src-cosmic-monitor
    "sha256-VAVvkBLB45NntP/YahrCzuaRjKw8h2pZd/T5+7fsH6U="; # cosmic-cargo-cosmic-monitor

  cosmic-notifications = mkCosmic "cosmic-notifications" "cosmic-notifications"
    "sha256-6Po/6VK1n8inpiMEESKwBHE0XL692XZj3w/R8evvh4I=" # cosmic-src-cosmic-notifications
    "sha256-32AoA17CO4noUzKhx+KDBpy5fWG4lvSBMK5aVJW8K9o="; # cosmic-cargo-cosmic-notifications

  cosmic-osd = mkCosmic "cosmic-osd" "cosmic-osd"
    "sha256-18QURT3L1RloFqsr9PR5Ts7YtbhmkCJU4w7E5d/OJIA=" # cosmic-src-cosmic-osd
    "sha256-5hput7WMstON8YG9GNNU61T+bQevGV72mAHYMtJJXng="; # cosmic-cargo-cosmic-osd

  cosmic-panel = mkCosmic "cosmic-panel" "cosmic-panel"
    "sha256-3nIlsngBTH7WZGVGjSeVvJUY3rWvORnfby0TfgiRWLg=" # cosmic-src-cosmic-panel
    "sha256-XIthlStPM97vjhJTdofUOkOudH1id6W2U4YdOxEh/eo="; # cosmic-cargo-cosmic-panel

  cosmic-player = mkCosmic "cosmic-player" "cosmic-player"
    "sha256-bqSUyBBB0aVk+wZZS++a+cYGWVyJYZqk5Utilz9mBEk=" # cosmic-src-cosmic-player
    "sha256-vrtcPq6322mm60IhULZts+QKgnlCShgm1I0xVjgo3Js="; # cosmic-cargo-cosmic-player

  cosmic-randr = mkCosmic "cosmic-randr" "cosmic-randr"
    "sha256-Jimw6YCRouG9FDlLBp15OOCRlywBIaP/K/bXLR7trQM=" # cosmic-src-cosmic-randr
    "sha256-QWSPj7bxxWh5/KeNEtUsfDKg+JMONLjomrMcn57j6fw="; # cosmic-cargo-cosmic-randr

  cosmic-screenshot = mkCosmic "cosmic-screenshot" "cosmic-screenshot"
    "sha256-RYvc/3FoRnNkuYBVfCG75Bmfb8JWW1H4GKXyhq7CxaQ=" # cosmic-src-cosmic-screenshot
    "sha256-q0RJST1yeqPBjU5MseNZIrZw+brfDtQLKiw7wyViflE="; # cosmic-cargo-cosmic-screenshot

  cosmic-session = mkCosmic "cosmic-session" "cosmic-session"
    "sha256-lL8is6WveKxOn/Ej3SrMfLrulnb+Qw9QAPcCbdLo07E=" # cosmic-src-cosmic-session
    "sha256-5dLG40X+yxJo566guyHqOCLNp+uNSE+HONS8GIDm58A="; # cosmic-cargo-cosmic-session

  cosmic-settings =
    let _src = fetchCosmic "cosmic-settings"
      "sha256-+MpSThb9+9S/M//eNKL6Yr+pphrHN/3vMDKT8lo7lT8="; # cosmic-src-cosmic-settings
    in prev.cosmic-settings.overrideAttrs (old: {
      version   = cosmicVersion;
      src       = _src;
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (old) pname;
        version = cosmicVersion;
        src     = _src;
        hash    = "sha256-+2Z0KbZKWbWtKA1jWY6/431i9/ax0ncivD2qzlNNIiE="; # cosmic-cargo-cosmic-settings
      };
      # dedup-libcosmic.patch targets old Cargo.lock; 1.4.0 fixes this upstream
      patches = [];
      # 1.4.0 added dav1d-sys which needs dav1d at build time
      buildInputs = (old.buildInputs or []) ++ [ final.dav1d ];
    });

  cosmic-settings-daemon =
    let _src = fetchCosmic "cosmic-settings-daemon"
      "sha256-j+AT56HYnenu5WQrBi9gqyog7oxDDf8vbUsKeGCiARM="; # cosmic-src-cosmic-settings-daemon
    in prev.cosmic-settings-daemon.overrideAttrs (old: {
      version   = cosmicVersion;
      src       = _src;
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (old) pname;
        version = cosmicVersion;
        src     = _src;
        hash    = "sha256-Le0FRKuSJWx6zRwU2b1+hyJzZJ+bsT039vn/Nhkf+k0="; # cosmic-cargo-cosmic-settings-daemon
      };
      # 1.4.0 added smithay-client-toolkit which needs xkbcommon at build time
      buildInputs = (old.buildInputs or []) ++ [ final.libxkbcommon ];
    });

  cosmic-store = mkCosmic "cosmic-store" "cosmic-store"
    "sha256-GEDsty2F52U1/WODd0a8n6GLX+2uyt6NOAxDOjzAnZo=" # cosmic-src-cosmic-store
    "sha256-a4LW9MrA/d6K6VfOp+8LFEBwvzxDDajJJ8txEHoN7TM="; # cosmic-cargo-cosmic-store

  cosmic-term = mkCosmic "cosmic-term" "cosmic-term"
    "sha256-CRBNxsKmSstm/rbn3SQgYlGfNYQCMSuz7kW+X+F3CsA=" # cosmic-src-cosmic-term
    "sha256-6a/9SwNJpGtTp0ofRmrxe0fCs6eNRLdxcKw44Qo7/cM="; # cosmic-cargo-cosmic-term

  cosmic-workspaces-epoch = mkCosmic "cosmic-workspaces-epoch" "cosmic-workspaces-epoch"
    "sha256-wKr388INojB3s5KJbcsVtNKFTBPUMc+QjAfxjGriSVo=" # cosmic-src-cosmic-workspaces-epoch
    "sha256-0ZvnMT7wkMyZ9zHOBGZNh+DmLaoATHvpSplSnVgC/j4="; # cosmic-cargo-cosmic-workspaces-epoch

  xdg-desktop-portal-cosmic = mkCosmic "xdg-desktop-portal-cosmic" "xdg-desktop-portal-cosmic"
    "sha256-8CpDyKq24PL89oky1NnfNa1W0c3A5gzv+sHk27zB5+Y=" # cosmic-src-xdg-desktop-portal-cosmic
    "sha256-Z5rszmonDnoplysE86ipNDWfh3QFW05sJsNxDbPi5Q8="; # cosmic-cargo-xdg-desktop-portal-cosmic

  # ── Non-Rust asset packages (src hash only, no cargo step) ────────────────

  cosmic-icons = mkCosmicAsset "cosmic-icons" "cosmic-icons"
    "sha256-QUTAYIQ6qAhjZK/9BZjJzTViECLUwO/MyaOqiRb1Ans="; # cosmic-src-cosmic-icons

  cosmic-sound-theme = mkCosmicAsset "cosmic-sound-theme" "cosmic-sound-theme"
    "sha256-hFWTn73SutdOZGbhkcsBR1TNabB+IOrxRndwXaikqN8="; # cosmic-src-cosmic-sound-theme

  cosmic-wallpapers = mkCosmicAsset "cosmic-wallpapers" "cosmic-wallpapers"
    "sha256-m2cYppfitpBDKK8CC9i/lUrC9rfSYTuqUSZSyIKKGyg="; # cosmic-src-cosmic-wallpapers

}
