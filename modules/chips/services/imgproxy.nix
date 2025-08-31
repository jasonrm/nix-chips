{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib; let
  inherit (chips.lib.traefik) hostRegexp;

  cfg = config.services.imgproxy;
in {
  options = with types; {
    services.imgproxy = {
      enable = mkEnableOption (mdDoc "Enable Imgproxy server.");
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
    programs.supervisord.programs = {
      imgproxy = {
        directory = config.dir.project;
        command = "${pkgs.imgproxy}/bin/imgproxy";
        environment = [
          "IMGPROXY_BIND=127.0.0.1:18080"
        ];
      };
    };
    services.nginx.virtualHosts.imgproxy =
      cfg.virtualHost
      // {
        serverName = "imgproxy.${config.project.domainSuffix}";
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:18080";
            proxyWebsockets = true;
          };
        };
      };
    services.traefik = {
      routers = {
        imgproxy = {
          service = "imgproxy";
          rule = hostRegexp ["imgproxy"] [config.project.domainSuffix];
        };
      };
      services = {
        imgproxy = {
          loadBalancer.servers = [
            {url = "http://127.0.0.1:18080";}
          ];
        };
      };
    };
  };
}
