# ===========================================================================
# modules/users/alex/screen-time/default.nix — alex's login hours
#
# Weekdays 08:00-21:00, weekends 08:00-22:00. Two parts:
#   1. pam_time blocks new logins outside those hours.
#   2. Timers warn alex 5 minutes before the cutoff, then end his session.
#
# The rule is added to "login" as a structured rule, NOT via .text: .text
# replaces the whole generated file, and greetd's own PAM file is nothing but
# include/substack login — that's what broke greetd on 2026-09-13. PAM_SERVICE
# stays "greetd" through the include, hence "greetd|login" in time.conf. Only
# lines naming alex restrict anyone, so the cosmic-greeter account and the
# other users pass through untouched.
#
# Imported by: Alex-Desktop, Alex-Laptop
# Rollback: drop the import from the host file and switch.
# ===========================================================================

{ pkgs, ... }:

let
  # The whole schedule. Warn times are the end times minus 5 minutes.
  user = "alex";
  start = "08:00";
  weekdayEnd = "21:00";  weekdayWarn = "20:55";
  weekendEnd = "22:00";  weekendWarn = "21:55";

  hhmm = builtins.replaceStrings [ ":" ] [ "" ]; # time.conf wants 0800

  # Re-checks the schedule so a Persistent catch-up run inside allowed hours
  # (e.g. at 8am boot) does nothing. 10# keeps 0800 from parsing as octal.
  logoutScript = pkgs.writeShellScript "alex-screen-time-logout" ''
    dow=$(date +%u) now=$(date +%H%M)
    if [ "$dow" -le 5 ]; then fin=${hhmm weekdayEnd}; else fin=${hhmm weekendEnd}; fi
    if [ $((10#$now)) -ge $((10#${hhmm start})) ] && [ $((10#$now)) -lt $((10#$fin)) ]; then
      exit 0
    fi
    ${pkgs.systemd}/bin/loginctl terminate-user ${user} 2>/dev/null || true
  '';

  warnScript = pkgs.writeShellScript "alex-screen-time-warn" ''
    bus=/run/user/$(${pkgs.coreutils}/bin/id -u ${user})/bus
    [ -S "$bus" ] || exit 0 # not logged in
    ${pkgs.util-linux}/bin/runuser -u ${user} -- env \
      DBUS_SESSION_BUS_ADDRESS=unix:path=$bus \
      ${pkgs.libnotify}/bin/notify-send -u critical -i appointment-soon \
      "5 minutes left" "Computer time is almost over. Save your game!" || true
  '';
in
{
  security.pam.services.login.rules.account.time = {
    order = 10900; # before pam_unix's account rule (11000)
    control = "required";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_time.so";
    args = [ "conffile=/etc/security/time.conf" ];
  };

  # services;ttys;users;times — Wk = Mon-Fri, Wd = Sat+Sun. conffile= above is
  # required: pam_time's built-in default is a read-only file in its store path.
  environment.etc."security/time.conf".text = ''
    greetd|login;*;${user};Wk${hhmm start}-${hhmm weekdayEnd}|Wd${hhmm start}-${hhmm weekendEnd}
  '';

  systemd.services.alex-screen-time-warn = {
    description = "Warn ${user} that screen time ends in 5 minutes";
    serviceConfig = { Type = "oneshot"; ExecStart = warnScript; };
  };
  systemd.timers.alex-screen-time-warn = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = [
      "Mon..Fri ${weekdayWarn}"
      "Sat,Sun ${weekendWarn}"
    ];
  };

  systemd.services.alex-screen-time-logout = {
    description = "End ${user}'s session outside allowed hours";
    serviceConfig = { Type = "oneshot"; ExecStart = logoutScript; };
  };
  systemd.timers.alex-screen-time-logout = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = [ "Mon..Fri ${weekdayEnd}" "Sat,Sun ${weekendEnd}" ];
      Persistent = true; # also fires on wake from sleep past the cutoff
    };
  };
}
