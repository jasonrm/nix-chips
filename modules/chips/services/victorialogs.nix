{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) escapeShellArgs mkEnableOption mkIf mkMerge mkOption types;

  cfg = config.services.victorialogs;
  httpAddress = "${cfg.host}:${toString cfg.portHttp}";
  syslogUdpAddress = "${cfg.syslogUdpHost}:${toString cfg.syslogUdpPort}";
  logsDomain = "logs.${config.project.domainSuffix}";

  args =
    [
      "-storageDataPath=${cfg.dataDir}"
      "-httpListenAddr=${httpAddress}"
    ]
    ++ lib.optionals cfg.syslogUdp.enable [
      "-syslog.listenAddr.udp=${syslogUdpAddress}"
    ]
    ++ cfg.extraArgs;

  environment =
    [
      "VICTORIALOGS_URL=http://${httpAddress}"
      "VICTORIALOGS_DOMAIN=${logsDomain}"
    ]
    ++ lib.optionals cfg.syslogUdp.enable [
      "SYSLOG_HOST=${cfg.syslogUdpHost}"
      "SYSLOG_PORT_UDP=${toString cfg.syslogUdpPort}"
    ];
in {
  options = {
    services.victorialogs = {
      enable = mkEnableOption "enable VictoriaLogs";

      package = mkOption {
        type = types.package;
        default = pkgs.victorialogs;
        description = "VictoriaLogs package to run.";
      };

      host = mkOption {
        type = types.str;
        default = config.project.address;
        description = "Address for the VictoriaLogs HTTP listener.";
      };

      portHttp = mkOption {
        type = types.int;
        default = config.ports.victorialogsHttp;
        description = "Port for the VictoriaLogs HTTP listener and web UI.";
      };

      dataDir = mkOption {
        type = types.str;
        default = "${config.dir.data}/victorialogs/data";
        description = "Directory where VictoriaLogs stores indexed log data.";
      };

      logDir = mkOption {
        type = types.str;
        default = "${config.dir.data}/victorialogs/logs";
        description = "Directory where supervisord writes the VictoriaLogs process logs.";
      };

      stdoutLogFile = mkOption {
        type = types.str;
        default = "${cfg.logDir}/stdout.log";
        description = "File where supervisord writes VictoriaLogs stdout.";
      };

      stderrLogFile = mkOption {
        type = types.str;
        default = "${cfg.logDir}/stderr.log";
        description = "File where supervisord writes VictoriaLogs stderr.";
      };

      syslogUdp = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable the VictoriaLogs UDP syslog listener.";
        };

        host = mkOption {
          type = types.str;
          default = config.project.address;
          description = "Address for the VictoriaLogs UDP syslog listener.";
        };

        port = mkOption {
          type = types.int;
          default = config.ports.victorialogsSyslogUdp;
          description = "Port for the VictoriaLogs UDP syslog listener.";
        };
      };

      syslogUdpHost = mkOption {
        type = types.str;
        default = cfg.syslogUdp.host;
        readOnly = true;
        description = "Resolved address for the VictoriaLogs UDP syslog listener.";
      };

      syslogUdpPort = mkOption {
        type = types.int;
        default = cfg.syslogUdp.port;
        readOnly = true;
        description = "Resolved port for the VictoriaLogs UDP syslog listener.";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional command-line arguments passed to victoria-logs.";
      };

      extraEnvironment = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional environment entries for the VictoriaLogs process.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      dir.ensureExists = [cfg.dataDir cfg.logDir];

      devShell = {
        contents = [cfg.package];
        environment = environment;
      };

      programs.supervisord = {
        programEnvironment = environment;
        syslog = lib.mkIf cfg.syslogUdp.enable {
          enable = true;
          host = cfg.syslogUdpHost;
          port = cfg.syslogUdpPort;
          excludePrograms = ["victorialogs"];
        };
        programs.victorialogs = {
          command = "${lib.getExe cfg.package} ${escapeShellArgs args}";
          environment = cfg.extraEnvironment;
          stdout_logfile = cfg.stdoutLogFile;
          stderr_logfile = cfg.stderrLogFile;
        };
      };

      services.phpfpm.extraPhpEnv = lib.mkIf cfg.syslogUdp.enable {
        SYSLOG_HOST = cfg.syslogUdpHost;
        SYSLOG_PORT_UDP = cfg.syslogUdpPort;
        VICTORIALOGS_URL = "http://${httpAddress}";
      };

      services.haproxy = {
        virtualHosts.logs = {
          host = logsDomain;
          backend = "victorialogs";
        };
        backends.victorialogs.servers = [
          {
            name = "victorialogs";
            address = httpAddress;
          }
        ];
        backends.victorialogs.extraConfig = ''
          http-request redirect location /select/vmui code 302 if { path / }
        '';
      };
    }
  ]);
}
