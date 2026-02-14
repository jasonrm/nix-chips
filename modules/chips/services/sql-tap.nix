{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.services.sql-tap;
  projectAddress = config.project.address;

  isAnyInstanceEnabled = foldl (x: y: x || y) false (mapAttrsToList (_: instance: instance.enable) cfg.instances);

  sortedNames = sort lessThan (attrNames cfg.instances);
  nameToIndex = listToAttrs (imap0 (i: name: {
    inherit name;
    value = i;
  }) sortedNames);

  moduleOptions = {name, config, ...}: let
    idx = nameToIndex.${name};
  in {
    options = with types; {
      enable = mkEnableOption "Enable this sql-tap instance";

      driver = mkOption {
        type = enum ["postgres" "mysql"];
        description = "Database driver (postgres or mysql).";
      };

      upstream = mkOption {
        type = str;
        description = "Upstream database address (e.g. localhost:5432).";
      };

      listenPort = mkOption {
        type = int;
        default = cfg.listenBasePort + idx;
        description = "Port for the sql-tap proxy to listen on.";
      };

      listen = mkOption {
        type = str;
        default = "${projectAddress}:${toString config.listenPort}";
        readOnly = true;
        description = "Computed listen address for the sql-tap proxy.";
      };

      grpcPort = mkOption {
        type = int;
        default = cfg.grpcBasePort + idx;
        description = "Port for the gRPC server.";
      };

      grpc = mkOption {
        type = str;
        default = "${projectAddress}:${toString config.grpcPort}";
        readOnly = true;
        description = "Computed gRPC address for the TUI client.";
      };

      dsnEnv = mkOption {
        type = str;
        default = "DATABASE_URL";
        description = "Environment variable containing DSN for EXPLAIN support.";
      };

      envFile = mkOption {
        type = str;
        default = "";
        description = "Path to an environment file to source before starting sql-tapd.";
      };
    };
  };
in {
  options = with types; {
    services.sql-tap = {
      listenBasePort = mkOption {
        type = int;
        default = 9081;
        description = "Base port for proxy listeners. Each instance gets base + index.";
      };

      grpcBasePort = mkOption {
        type = int;
        default = 9091;
        description = "Base port for gRPC servers. Each instance gets base + index.";
      };

      instances = mkOption {
        type = attrsOf (submodule moduleOptions);
        default = {};
        description = "sql-tap proxy instances.";
      };
    };
  };

  config = lib.mkIf isAnyInstanceEnabled (mkMerge (
    mapAttrsToList (
      name: opts:
        if opts.enable
        then let
          sqltapdExec = pkgs.writeShellScriptBin "sql-tapd-${name}" ''
            if [[ -f "${opts.envFile}" ]]; then
              set -o allexport
              source "${opts.envFile}"
              set +o allexport
            fi
            exec ${pkgs.sql-tap}/bin/sql-tapd \
              -driver ${opts.driver} \
              -listen ${opts.listen} \
              -upstream ${opts.upstream} \
              -grpc ${opts.grpc} \
              -dsn-env ${opts.dsnEnv}
          '';
        in {
          programs.supervisord.programs."sql-tapd-${name}" = {
            command = "${sqltapdExec}/bin/sql-tapd-${name}";
          };
          devShell.contents = [
            (pkgs.writeShellScriptBin "sql-tap-${name}" ''
              exec ${pkgs.sql-tap}/bin/sql-tap ${opts.grpc}
            '')
          ];
        }
        else {}
    )
    cfg.instances
  ));
}
