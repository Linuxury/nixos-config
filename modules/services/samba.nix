# ===========================================================================
# modules/services/samba.nix — Samba file server (common base config)
#
# This module sets up the shared foundation for any host running Samba:
#   - Global Samba settings (security, protocol, performance)
#   - Windows network discovery via wsdd
#   - macOS/Linux discovery via Avahi
#   - Firewall ports opened automatically
#
# SHARES are NOT defined here — they belong in each host's config because
# every server has different storage and different access requirements.
# In the host config, add your shares under:
#
#   services.samba.shares = {
#     shareName = {
#       path         = "/the/path";
#       browseable   = "yes";
#       "read only"  = "yes";
#       "valid users"= "linuxury babylinux alex";
#     };
#   };
#
# SAMBA PASSWORDS must be set manually after first boot — they are separate
# from the Linux user password. Run for each user:
#   sudo smbpasswd -a linuxury
#   sudo smbpasswd -a babylinux
#   sudo smbpasswd -a alex
#
# To verify shares are accessible from another machine:
#   smbclient -L //<hostname> -U linuxury
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  # =========================================================================
  # Samba — SMB file server
  #
  # "security = user" means every connection requires a Samba username and
  # password. There is no guest/anonymous access ("map to guest = Bad User"
  # rejects connections that don't match a valid Samba account).
  #
  # Protocol is locked to SMB2+ — SMB1 is ancient, insecure, and removed
  # from modern Windows anyway. SMB3 is preferred for newer clients.
  # =========================================================================
  services.samba = {
    enable      = true;
    openFirewall = true;

    # Enable nmbd — NetBIOS Name Service
    # Allows Windows machines to find the server by hostname.
    # Without this, Windows clients need the IP address directly.
    enableNmbd = true;

    extraConfig = ''
      # -------------------------------------------------------------------
      # Identity
      # -------------------------------------------------------------------
      workgroup    = WORKGROUP
      server string = %h

      # -------------------------------------------------------------------
      # Security — authenticated access only, no guest
      # -------------------------------------------------------------------
      security      = user
      passdb backend = tdbsam
      map to guest  = Bad User

      # -------------------------------------------------------------------
      # Restrict to modern SMB protocol versions
      # SMB1 is disabled — it has known security vulnerabilities (EternalBlue)
      # and is not needed for any current OS (Windows 7+, macOS, Linux)
      # -------------------------------------------------------------------
      min protocol = SMB2
      max protocol = SMB3

      # -------------------------------------------------------------------
      # Performance tuning
      # -------------------------------------------------------------------
      socket options   = TCP_NODELAY IPTOS_LOWDELAY
      use sendfile     = yes
      aio read size    = 16384
      aio write size   = 16384

      # -------------------------------------------------------------------
      # macOS compatibility — makes shares work well in Finder
      # -------------------------------------------------------------------
      vfs objects    = fruit streams_xattr
      fruit:metadata = stream
      fruit:model    = MacSamba
      fruit:veto_appledouble = no
      fruit:posix_rename     = yes
      fruit:zero_file_id     = yes
      fruit:wipe_intentionally_left_blank_rfork = yes
      fruit:delete_empty_adfiles = yes

      # -------------------------------------------------------------------
      # Logging — minimal, errors only
      # -------------------------------------------------------------------
      log level    = 1
      log file     = /var/log/samba/%m.log
      max log size = 50
    '';
  };

  # =========================================================================
  # wsdd — Web Services Dynamic Discovery
  #
  # Makes Samba shares discoverable on the Windows "Network" browser
  # (the modern replacement for the old NetBIOS broadcast discovery).
  # Without this, Windows 10/11 won't show the server in File Explorer
  # even when SMB is working perfectly.
  # =========================================================================
  services.wsdd = {
    enable      = true;
    openFirewall = true;
  };

  # =========================================================================
  # Avahi — mDNS/Bonjour network discovery
  #
  # Makes the Samba server discoverable on macOS and Linux.
  # macOS Finder shows it under "Network" in the sidebar.
  # Linux file managers (Nautilus, Dolphin) find it automatically.
  # =========================================================================
  services.avahi = {
    enable   = true;
    nssmdns4 = true;  # Enables .local hostname resolution
    publish = {
      enable      = true;
      addresses   = true;  # Publish IP address
      workstation = true;  # Show up as a workstation in network browsers
    };
  };

  # services.samba.enable already adds the samba package (incl. smbclient,
  # smbstatus, pdbedit) to the system profile — no need to list it here.
}
