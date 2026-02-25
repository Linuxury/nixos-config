# ===========================================================================
# modules/base/snapper.nix — Automatic BTRFS snapshots
#
# Included in common.nix so it runs on every host.
#
# WHAT IT DOES:
#   - Takes hourly snapshots of / (the @ subvolume) and /home (@home)
#   - Automatically prunes old snapshots on a timeline:
#       8 hourly    → covers the last 8 hours
#       7 daily     → one per day for a week
#       4 weekly    → one per week for a month
#   - Monthly BTRFS scrub to catch silent data corruption early
#
# ALL hosts use BTRFS and mount /.snapshots from @snapshots, so this
# works everywhere without host-specific configuration.
#
# USEFUL COMMANDS (see fish abbreviations too):
#   sudo snapper -c root list           # list system snapshots
#   sudo snapper -c home list           # list home snapshots
#   sudo snapper -c root create --description "before update"  # manual snapshot
#   sudo snapper -c root undochange 5..0 /etc/someconfig       # restore a file
# ===========================================================================

{ ... }:

{
  services.snapper = {
    # How often to run the cleanup daemon (not the snapshot creation)
    cleanupInterval  = "1d";
    # How often to take new snapshots (the actual snapshot trigger interval)
    snapshotInterval = "hourly";

    configs = {

      # -----------------------------------------------------------------------
      # root — snapshots of the system root (/ → @)
      #
      # Catches OS changes: package installs, config edits, system updates.
      # These are what you roll back when a rebuild breaks something.
      # -----------------------------------------------------------------------
      root = {
        SUBVOLUME        = "/";
        ALLOW_USERS      = [];           # root only
        TIMELINE_CREATE  = true;         # take snapshots on the schedule
        TIMELINE_CLEANUP = true;         # prune old ones automatically
        TIMELINE_LIMIT_HOURLY  = "8";
        TIMELINE_LIMIT_DAILY   = "7";
        TIMELINE_LIMIT_WEEKLY  = "4";
        TIMELINE_LIMIT_MONTHLY = "0";   # disabled — weekly is enough coverage
        TIMELINE_LIMIT_YEARLY  = "0";
      };

      # -----------------------------------------------------------------------
      # home — snapshots of /home (→ @home)
      #
      # Catches user data changes: documents, configs, game saves.
      # Useful for recovering accidentally deleted or overwritten files.
      # -----------------------------------------------------------------------
      home = {
        SUBVOLUME        = "/home";
        ALLOW_USERS      = [];
        TIMELINE_CREATE  = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY  = "8";
        TIMELINE_LIMIT_DAILY   = "7";
        TIMELINE_LIMIT_WEEKLY  = "4";
        TIMELINE_LIMIT_MONTHLY = "0";
        TIMELINE_LIMIT_YEARLY  = "0";
      };

    };
  };

  # ===========================================================================
  # BTRFS auto-scrub
  #
  # Scrubbing reads every block on the filesystem and verifies checksums.
  # It catches and repairs silent data corruption (bad sectors, bit rot)
  # before it causes data loss. On BTRFS with single-disk, it can detect
  # errors even if it can't always repair them — you'd know to act.
  #
  # Once a month is the standard recommendation.
  # ===========================================================================
  services.btrfs.autoScrub = {
    enable      = true;
    interval    = "monthly";
    fileSystems = [ "/" ];  # scrubs the device backing /, which covers all
                            # subvolumes on the same disk (home, nix, etc.)
  };
}
