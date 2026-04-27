{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.psd;
in
{
  options.services.psd = with lib.types; {
    enable = lib.mkOption {
      type = bool;
      default = false;
      description = ''
        Whether to enable the Profile Sync daemon.
      '';
    };

    package = lib.mkPackageOption pkgs "profile-sync-daemon" { };

    resyncTimer = lib.mkOption {
      type = str;
      default = "1h";
      example = "1h 30min";
      description = ''
        The amount of time to wait before syncing browser profiles back to the
        disk.

        Takes a systemd.unit time span. The time unit defaults to seconds if
        omitted.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      user = {
        services = {
          psd = {
            enable = true;
            description = "Profile Sync daemon";
            wants = [ "psd-resync.service" ];
            wantedBy = [ "default.target" ];
            bindsTo = [ "psd.service" ];
            unitConfig = {
              RequiresMountsFor = [ "/home/" ];
            };
            environment = {
              LAUNCHED_BY_SYSTEMD = "1";
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = "yes";
              ExecStart = "${cfg.package}/bin/profile-sync-daemon startup";
              ExecStartPost = "${cfg.package}/bin/profile-sync-daemon resync";
              ExecStop = "${cfg.package}/bin/profile-sync-daemon unsync";
            };
          };

          psd-resync = {
            enable = true;
            description = "Timed profile resync";
            after = [ "psd.service" ];
            bindsTo = [ "psd.service" ];
            wants = [ "psd-resync.timer" ];
            wantedBy = [ "default.target" ];
            environment = {
              LAUNCHED_BY_SYSTEMD = "1";
            };
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${cfg.package}/bin/profile-sync-daemon resync";
            };
          };
        };

        timers.psd-resync = {
          description = "Timer for profile sync daemon - ${cfg.resyncTimer}";
          bindsTo = [ "psd.service" ];

          timerConfig = {
            OnUnitActiveSec = "${cfg.resyncTimer}";
          };
        };
      };
    };
  };
}
