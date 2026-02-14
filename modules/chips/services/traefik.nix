{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    types
    mkMerge
    mkIf
    filterAttrs
    optionals
    mapAttrs
    elemAt
    ;
  inherit (pkgs) writeText;

  cfg = config.services.traefik;

  httpsEnabled = cfg.certificatesResolvers != {};

  innerConfig = {
    http = lib.filterAttrs (n: v: v != {}) {
      inherit (cfg) middlewares services;
      routers =
        {
          traefik = {
            entryPoints = ["traefik"];
            service = "api@internal";
            rule = "PathPrefix(`/`)";
          };
        }
        // cfg.routers;
    };
  };

  staticConfDir = pkgs.writeTextFile {
    name = "traefik-conf";
    destination = "/static.yaml";
    text = builtins.toJSON innerConfig;
  };

  serverConfig = lib.filterAttrs (n: v: v != {}) {
    inherit (cfg) certificatesResolvers;

    entryPoints =
      mapAttrs (
        k: v:
          lib.filterAttrs (n: v: v != {}) {
            http = v.http or {};
            address = "${config.project.address}:${toString v.port}";
          }
      )
      cfg.entryPoints;

    api = {
      dashboard = true;
    };

    log = {
      level = cfg.logLevel;
    };

    pilot.dashboard = false;

    providers.file = {
      filename = "${staticConfDir}/static.yaml";
    };
  };

  traefikConf = writeText "traefik.yaml" (builtins.toJSON serverConfig);

  # TODO: Make this more generic (e.g. binWithEnv)
  traefikExec = pkgs.writeShellScriptBin "traefik-exec" ''
    if [[ -f "${cfg.environmentFile}" ]]; then
      set -o allexport
      source "${cfg.environmentFile}"
      set +o allexport
    fi
    exec ${pkgs.traefik}/bin/traefik --configfile=${traefikConf}
  '';
in {
  options = with types; {
    services.traefik = {
      enable = mkEnableOption "enable traefik";
      enableHttps = mkEnableOption "enable HTTPS entry point";
      debug = mkEnableOption "debug";
      logLevel = mkOption {
        type = str;
        default = "error";
      };
      environment = mkOption {
        type = listOf str;
        default = [];
      };
      environmentFile = mkOption {
        type = str;
        default = "";
      };
      domains = mkOption {
        type = listOf str;
        default = ["localhost"];
      };
      certificatesResolvers = mkOption {
        type = attrs;
        default = {};
      };
      middlewares = mkOption {
        type = attrs;
        default = {};
      };
      routers = mkOption {
        type = attrs;
        default = {};
      };
      services = mkOption {
        type = attrs;
        default = {};
      };
      entryPoints = {
        http = {
          port = mkOption {
            type = int;
            default = config.ports.http;
          };
        };
        traefik = {
          port = mkOption {
            type = int;
            default = config.ports.traefik;
          };
        };
        https = {
          port = mkOption {
            type = int;
            default = config.ports.https;
          };
          http = mkOption {
            type = attrs;
            default = {};
          };
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      programs.supervisord.programs.traefik = {
        command =
          if pkgs.stdenv.isDarwin
          then "sudo -E ${traefikExec}/bin/traefik-exec"
          else "${traefikExec}/bin/traefik-exec";
        environment = cfg.environment;
      };
    })
    (mkIf cfg.debug {
      devShell.shellHooks = [
        ''echo traefik config: ${traefikConf}''
        ''echo traefik static config: ${staticConfDir}/static.yaml''
      ];
    })
  ];
}
