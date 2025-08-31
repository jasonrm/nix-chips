{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib;
let
  inherit (chips.lib.traefik) hostRegexp;

  cfg = config.services.imgproxy;

  schema = if config.programs.lego.enable then "https" else "http";
in
{
  options = with types; {
    services.imgproxy = {
      enable = mkEnableOption (mdDoc "Enable Imgproxy server.");

      virtualHost = mkOption {
        type = submodule (import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix");
        default = { };
        description = mdDoc ''
          Nginx configuration can be done by adapting {option}`services.nginx.virtualHosts`.
          See [](#opt-services.nginx.virtualHosts) for further information.
        '';
      };

      port = mkOption {
        type = int;
        default = 18080;
        description = "Port to run Imgproxy server on.";
      };
    };
  };

  config = mkIf cfg.enable {
    devShell = {
      environment = [
        "IMGPROXY_BASE_URI=${schema}://imgproxy.${config.project.domainSuffix}"
        "IMGPROXY_PORT=${toString cfg.port}"
        "IMGPROXY_DOMAIN=imgproxy.${config.project.domainSuffix}"
      ];
    };

    services.php = {
      phpEnv = {
        "IMGPROXY_BASE_URI" = "${schema}://imgproxy.${config.project.domainSuffix}";
      };
    };
    programs = {

      supervisord.programs = {
        imgproxy = {
          directory = config.dir.project;
          command = "${pkgs.imgproxy}/bin/imgproxy";
          environment = [ "IMGPROXY_BIND=127.0.0.1:${toString cfg.port}" ];
          autostart = true;
          stderr_logfile = "/dev/stderr";
        };
      };
    };

    services.nginx.virtualHosts.imgproxy =
      cfg.virtualHost
      // {
        serverName = "imgproxy.${config.project.domainSuffix}";
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
          };
        };
      }
      // (optionalAttrs config.programs.lego.enable {
        onlySSL = true;
        sslCertificate = config.programs.lego.certFile;
        sslCertificateKey = config.programs.lego.keyFile;
      });

    services.traefik = {
      routers = {
        imgproxy = {
          service = "imgproxy";
          rule = hostRegexp [ "imgproxy" ] [ config.project.domainSuffix ];
        };
      };
      services = {
        imgproxy = {
          loadBalancer.servers = [ { url = "http://127.0.0.1:${toString cfg.port}"; } ];
        };
      };
    };
  };
}
