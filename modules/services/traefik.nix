{ lib, pkgs, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkMerge mkIf filterAttrs optionals mapAttrs;
  inherit (pkgs) writeText;

  cfg = config.services.traefik;

  httpsEnabled = cfg.certificatesResolvers != { };

  innerConfig = {
    http = lib.filterAttrs (n: v: v != { }) {
      inherit (cfg) middlewares services;
      routers = {
        traefik = {
          entryPoints = [ "http" ] ++ optionals httpsEnabled [ "https" ];
          service = "api@internal";
          rule = "Host(`traefik.localhost`, `traefik.${cfg.domain}`)";
        };
      } // cfg.routers;
    };
  };

  staticConfDir = pkgs.writeTextFile {
    name = "traefik-conf";
    destination = "/static.yaml";
    text = (builtins.toJSON innerConfig);
  };

  serverConfig = lib.filterAttrs (n: v: v != { }) {
    inherit (cfg) certificatesResolvers;

    entryPoints = mapAttrs
      (k: v: {
        address = ":${toString v.port}";
      })
      cfg.entryPoints;

    api = { dashboard = true; };

    providers.file = {
      filename = "${staticConfDir}/static.yaml";
    };
  };

  traefikConf = writeText "traefik.yaml" (builtins.toJSON serverConfig);
in
{
  options = with types; {
    services.traefik = {
      enable = mkEnableOption "enable traefik";
      domain = mkOption {
        type = str;
        default = "localhost";
      };
      certificatesResolvers = mkOption {
        type = attrs;
        default = { };
      };
      middlewares = mkOption {
        type = attrs;
        default = { };
      };
      routers = mkOption {
        type = attrs;
        default = { };
      };
      services = mkOption {
        type = attrs;
        default = { };
      };
      entryPoints = {
        http = {
          port = mkOption {
            type = int;
            default = config.ports.http;
          };
        };
        https = {
          port = mkOption {
            type = int;
            default = config.ports.https;
          };
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      programs.supervisord.programs.traefik = {
        command = "${pkgs.traefik}/bin/traefik --configfile=${traefikConf} --log=true --log.level=error";
      };
      shell.shellHooks = [
        ''echo traefik static config: ${staticConfDir}/static.yaml''
      ];
    })
  ];
}
