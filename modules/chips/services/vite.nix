{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib; let
  inherit (chips.lib.traefik) hostRegexp;

  cfg = config.services.vite;
in {
  options = with types; {
    services.vite = {
      enable = mkEnableOption (mdDoc "Enable Vite dev server.");
      virtualHost = mkOption {
        type = submodule (import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix");
        default = {};
        description = mdDoc ''
          Nginx configuration can be done by adapting {option}`services.nginx.virtualHosts`.
          See [](#opt-services.nginx.virtualHosts) for further information.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    programs = {
      supervisord = {
        enable = true;
        programs = {
          vite = {
            autostart = true;
            directory = config.dir.project;
            stderr_logfile = "/dev/stderr";
            command = "${pkgs.nodejs}/bin/node ./node_modules/vite/bin/vite.js dev --strictPort --host 127.0.0.1 --port 5173";
          };
        };
      };
    };
    services.nginx = {
      virtualHosts = {
        vite =
          cfg.virtualHost
          // {
            serverName = "vite.${config.project.domainSuffix}";
            locations = {
              "/" = {
                proxyPass = "http://127.0.0.1:5173";
                proxyWebsockets = true;
              };
            };
          };
      };
    };
    services.traefik = {
      routers = {
        vite = {
          service = "vite";
          rule = hostRegexp ["vite"] [config.project.domainSuffix];
        };
      };
      services = {
        vite = {
          loadBalancer.servers = [
            {url = "http://127.0.0.1:5173";}
          ];
        };
      };
    };
  };
}
