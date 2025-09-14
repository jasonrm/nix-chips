{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.programs.supervisord;

  inherit (builtins) concatStringsSep;

  programEntry = name: attrs: ''
    [program:${name}]
    ${generators.toKeyValue {} (mapAttrs prepProgramAttrs (filterAttrs programAttrFilter attrs))}
  '';

  programAttrFilter = n: v:
    if v == null
    then false
    else if v == ""
    then false
    else if v == {}
    then false
    else if v == []
    then false
    else true;

  prepProgramAttrs = name: value:
    if isList value
    then concatStringsSep "," value
    else value;

  programEntries = attrsets.mapAttrsToList programEntry cfg.programs;
  configuration = pkgs.writeText "supervisord.ini" ''
    [inet_http_server]
    port=127.0.0.1:${toString cfg.port}

    ${(concatStringsSep "" programEntries)}
  '';

  programOption = with types;
    {name, ...}: {
      options = {
        autostart = mkOption {
          type = bool;
          default = true;
          description = "Should the supervised command run on supervisord start? Defaults to true.";
        };
        autorestart = mkOption {
          type = bool;
          default = true;
        };
        user = mkOption {
          type = nullOr str;
          default = null;
        };
        group = mkOption {
          type = nullOr str;
          default = null;
        };
        stopsignal = mkOption {
          type = nullOr str;
          default = null;
        };
        command = mkOption {
          type = oneOf [
            path
            str
          ];
          description = "Command to supervise. It can be given as full path to executable or can be calculated via PATH variable. Command line parameters also should be supplied in this string.";
        };
        stdout_logfile = mkOption {
          type = path;
          default = "/dev/stdout";
        };
        stderr_logfile = mkOption {
          type = path;
          default = "/dev/stderr";
        };
        stopasgroup = mkOption {
          type = bool;
          default = true;
        };
        killasgroup = mkOption {
          type = bool;
          default = true;
        };
        startsecs = mkOption {
          type = nullOr int;
          default = null;
        };
        stopwaitsecs = mkOption {
          type = nullOr int;
          default = null;
        };
        killwaitsecs = mkOption {
          type = nullOr int;
          default = null;
        };
        directory = mkOption {
          type = nullOr str;
          default = config.dir.data + "/${name}/run";
        };
        environment = mkOption {
          type = listOf str;
          default = [];
        };
        envFiles = mkOption {
          type = nullOr (
            listOf (oneOf [
              path
              str
            ])
          );
          default = [];
        };
        depends_on = mkOption {
          type = listOf str;
          default = [];
        };
        restartpause = mkOption {
          type = nullOr int;
          default = null;
          description = "Wait (at least) this amount of seconds after stopping supervised program before starting it again.";
        };
        restart_when_binary_changed = mkOption {
          type = bool;
          default = false;
          description = "Boolean value (false or true) to control if the supervised command should be restarted when its executable binary changes. Defaults to false.";
        };
        restart_cmd_when_binary_changed = mkOption {
          type = nullOr str;
          default = null;
          description = "The command to restart the program if the program binary itself is changed.";
        };
        restart_signal_when_binary_changed = mkOption {
          type = nullOr str;
          default = null;
          description = "The signal sent to the program for restarting if the program binary is changed.";
        };
        restart_directory_monitor = mkOption {
          type = nullOr str;
          default = null;
          description = "Path to be monitored for restarting purpose.";
        };
        restart_file_pattern = mkOption {
          type = nullOr str;
          default = null;
          description = "If a file changes under restart_directory_monitor and filename matches this pattern, the supervised command will be restarted.";
        };
        restart_cmd_when_file_changed = mkOption {
          type = nullOr str;
          default = null;
          description = "The command to restart the program if any monitored files under restart_directory_monitor with pattern restart_file_pattern are changed.";
        };
        restart_signal_when_file_changed = mkOption {
          type = nullOr str;
          default = null;
          description = "The signal will be sent to the proram, such as Nginx, for restarting if any monitored files under restart_directory_monitor with pattern restart_file_pattern are changed.";
        };
      };
    };

  programRunDirectories =
    attrsets.mapAttrsToList (
      name: programOption: programOption.directory
    )
    cfg.programs;

  supervisord-debug = pkgs.writeShellScriptBin "supervisord-debug" ''
    cat ${configuration}
  '';

  supervisord = pkgs.writeShellScriptBin "supervisord" ''
    ${pkgs.coreutils}/bin/mkdir -p ${concatStringsSep " " (map escapeShellArg programRunDirectories)}
    ${pkgs.supervisord-go}/bin/supervisord --configuration=${configuration} $*
  '';
in {
  imports = [
    # paths to other modules
  ];

  options = with types; {
    programs.supervisord = {
      enable = mkEnableOption "use supervisord";
      user = mkOption {
        type = nullOr str;
        default = "http";
      };
      group = mkOption {
        type = nullOr str;
        default = "http";
      };
      port = mkOption {
        type = int;
        default = config.ports.supervisord;
      };
      programs = mkOption {
        default = {};
        type = attrsOf (submodule programOption);
      };

      output = mkOption {
        type = package;
        readOnly = true;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enable -> config.dir.project == "/dev/null";
        message = "cfg.enable cannot be set without also setting config.dir.project ";
      }
    ];

    programs.supervisord.programs =
      mapAttrs (
        name: service: let
          beforeServices = filter isString (
            mapAttrsToList (
              beforeName: service:
                if (any (v: v == "${name}.service") service.before)
                then beforeName
                else null
            )
            config.systemd.services
          );
          afterServices = filter (v: hasAttrByPath [v] config.programs.supervisord.programs) (
            map (removeSuffix ".service") service.after
          );
          baseEnvFile = pkgs.writeText "${name}.env" (
            concatStringsSep "\n" (mapAttrsToList (name: value: "${name}=${value}") service.environment)
          );
          additionalEnv = (
            optionals (hasAttrByPath ["serviceConfig" "EnvironmentFile"] service) (
              map toString (
                if service.serviceConfig.EnvironmentFile == null
                then []
                else if isList service.serviceConfig.EnvironmentFile
                then service.serviceConfig.EnvironmentFile
                else [service.serviceConfig.EnvironmentFile]
              )
            )
          );
        in
          filterAttrs (n: v: v != {}) {
            autostart = mkDefault (service.wantedBy != []);
            command = mkDefault "${service.serviceConfig.ExecStart}";
            depends_on = mkDefault (beforeServices ++ afterServices);
            envFiles = [baseEnvFile] ++ additionalEnv;
          }
          // (optionalAttrs (hasAttrByPath ["serviceConfig" "WorkingDirectory"] service) {
            directory = "${service.serviceConfig.WorkingDirectory}";
          })
          // (optionalAttrs (hasAttrByPath ["serviceConfig" "Type"] service) {
            autorestart =
              if service.serviceConfig.Type == "oneshot"
              then false
              else true;
          })
      )
      config.systemd.services;

    devShell = {
      contents = [
        supervisord
        supervisord-debug
      ];
    };

    programs.supervisord.output = supervisord;

    services.traefik = {
      routers = {
        supervisord = {
          service = "supervisord";
          rule = "Host(`supervisord.localhost`)";
        };
      };
      services = {
        supervisord = {
          loadBalancer.servers = [{url = "http://127.0.0.1:${toString cfg.port}";}];
        };
      };
    };
  };
}
