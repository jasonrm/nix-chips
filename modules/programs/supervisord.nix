{ system, lib, pkgs, config, ... }:
let
  inherit (lib) mkOption escapeShellArg;

  cfg = config.programs.supervisord;

  inherit (builtins) concatStringsSep;

  toStr = value:
    if true == value then "true"
    else if false == value then "false"
    else toString value;

  programEntry = name: attrs: ''
    [program:${name}]
    ${lib.generators.toKeyValue { } (lib.mapAttrs prepProgramAttrs (lib.filterAttrs programAttrFilter attrs))}
  '';

  programAttrFilter = n: v:
    if v == null then false
    else if v == "" then false
    else if v == { } then false
    else if v == [ ] then false
    else true;

  prepProgramAttrs = name: value:
    if name == "environment" then concatStringsSep "," value
    else value;

  programEntries = lib.attrsets.mapAttrsToList programEntry cfg.programs;
  configuration = pkgs.writeText "supervisord.ini" ''
    [inet_http_server]
    port=127.0.0.1:${toString cfg.port}

    ${(concatStringsSep "" programEntries)}
  '';

  programOption = with lib.types; { name, ... }:
    let
      programOption = cfg.programs.${name};
    in
    {
      options = {
        autostart = mkOption {
          type = bool;
          default = true;
        };
        autorestart = mkOption {
          type = bool;
          default = false;
        };
        # user = mkOption {
        #   type = nullOr str;
        #   default = config.default.user;
        # };
        # group = mkOption {
        #   type = nullOr str;
        #   default = config.default.group;
        # };
        stopsignal = mkOption {
          type = nullOr str;
          default = null;
        };
        command = mkOption {
          type = oneOf [ path str ];
        };
        stdout_logfile = mkOption {
          type = path;
          default = "${config.dir.log}/${name}.stdout.log";
        };
        stderr_logfile = mkOption {
          type = path;
          default = "${config.dir.log}/${name}.stderr.log";
        };
        stopasgroup = mkOption {
          type = bool;
          default = true;
        };
        killasgroup = mkOption {
          type = bool;
          default = true;
        };
        stopwaitsecs = mkOption {
          type = int;
          default = 5;
        };
        directory = mkOption {
          type = nullOr str;
          default = config.dir.run;
        };
        environment = mkOption {
          type = listOf str;
          default = [ ];
        };
      };
      #    config = let
      #      envVars = programOption.environment;
      #    in {
      #      environment = if lib.isAttrs envVars then () else envVars;
      #    };
    };

  supervisord-debug = (pkgs.writeShellScriptBin "supervisord-debug" ''
    cat ${configuration}
  '');

  supervisord = (pkgs.writeShellScriptBin "supervisord" ''
    echo supervisord config: ${configuration}
    mkdir -p ${lib.concatStringsSep " " (map escapeShellArg config.dir.ensureExists)}
    ${pkgs.staging.supervisord-go}/bin/supervisord --configuration=${configuration} $*
  '');

in
{
  imports = [
    # paths to other modules
  ];

  options = with lib.types;  {
    programs.supervisord = {
      enable = lib.mkEnableOption "use supervisord";
      debug = lib.mkEnableOption "debug supervisord configuration";
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
        default = { };
        type = attrsOf (submodule programOption);
      };
    };
  };

  config = {
    shell = lib.mkIf cfg.enable {
      contents = [
        supervisord
        supervisord-debug
      ];
    };

    outputs.apps = {
      supervisord = {
        program = "${supervisord}/bin/supervisord";
      };
    };
  };
}
