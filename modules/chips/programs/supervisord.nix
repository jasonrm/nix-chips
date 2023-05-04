{
  system,
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.programs.supervisord;

  inherit (builtins) concatStringsSep;

  toStr = value:
    if true == value
    then "true"
    else if false == value
    then "false"
    else toString value;

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
    {name, ...}: let
      programOption = cfg.programs.${name};
    in {
      options = {
        autostart = mkOption {
          type = bool;
          default = true;
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
          type = oneOf [path str];
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
          default = false;
        };
        killasgroup = mkOption {
          type = bool;
          default = false;
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
        depends_on = mkOption {
          type = listOf str;
          default = [];
        };
      };
    };

  programRunDirectories = attrsets.mapAttrsToList (name: programOption: programOption.directory) cfg.programs;

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
          beforeServices = filter isString (mapAttrsToList (beforeName: service:
            if (any (v: v == "${name}.service") service.before)
            then beforeName
            else null)
          config.systemd.services);
          afterServices = filter (v: hasAttrByPath [v] config.programs.supervisord.programs) (map (removeSuffix ".service") service.after);
        in
          filterAttrs (n: v: v != {}) {
            autostart = mkDefault (service.wantedBy != []);
            command = mkDefault "${service.serviceConfig.ExecStart}";
            depends_on = mkDefault (beforeServices ++ afterServices);
            environment = mapAttrsToList (name: value: "${name}=${value}") service.environment;
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

    chips.devShell = {
      contents = [
        supervisord
        supervisord-debug
      ];
    };
    services.traefik = {
      routers = {
        supervisord = {
          service = "supervisord";
          rule = "Host(`supervisord.localhost`)";
        };
      };
      services = {
        supervisord = {
          loadBalancer.servers = [
            {url = "http://127.0.0.1:${toString cfg.port}";}
          ];
        };
      };
    };
  };
}
