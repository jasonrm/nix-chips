{ lib, pkgs, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkMerge mkIf filterAttrs;
  inherit (pkgs) writeText;

  cfg = config.services.traefik;

  innerConfig = {
    http = lib.filterAttrs (n: v: v != { }) {
      inherit (cfg) middlewares routers services;
    };
  };

  staticConfDir = pkgs.writeTextFile {
    name = "traefik-conf";
    destination = "/static.yaml";
    text = (builtins.toJSON innerConfig);
  };

  serverConfig = lib.filterAttrs (n: v: v != { }) {
    inherit (cfg) certificatesResolvers;

    entryPoints.http = {
      address = ":${toString cfg.port}";
    };

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
      port = mkOption {
        type = int;
        default = config.ports.traefik;
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      programs.supervisord.programs.traefik = {
        command = "${pkgs.traefik}/bin/traefik --configfile=${traefikConf} --log=true --log.level=error";
      };
    })
  ];
}
