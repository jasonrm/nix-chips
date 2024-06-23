{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib; let
  inherit (chips.lib.traefik) hostRegexp;

  cfg = config.programs.vite;
  nginx = config.services.nginx;

  schema =
    if config.programs.lego.enable
    then "https"
    else "http";
in {
  options = with types; {
    programs.vite = {
      enable = mkEnableOption (mdDoc "Enable Vite dev server.");

      virtualHost = mkOption {
        type = submodule (import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix");
        default = {};
        description = mdDoc ''
          Nginx configuration can be done by adapting {option}`services.nginx.virtualHosts`.
          See [](#opt-services.nginx.virtualHosts) for further information.
        '';
      };

      port = mkOption {
        type = int;
        default = 5173;
        description = "Port to run Vite dev server on.";
      };
    };
  };

  config = mkIf cfg.enable {
    devShell = {
      environment = [
        "VITE_BASE_URI=${schema}://vite.${config.project.domainSuffix}"
        "RESOURCES_BASE_URI=${schema}://vite.${config.project.domainSuffix}"
        "VITE_PORT=${toString cfg.port}"
        "VITE_DOMAIN=vite.${config.project.domainSuffix}"
      ];
    };
    programs = {
      phpApp = {
        phpEnv = {
          "VITE_BASE_URI" = "${schema}://vite.${config.project.domainSuffix}";
          "RESOURCES_BASE_URI" = "${schema}://vite.${config.project.domainSuffix}";
        };
      };
      supervisord = {
        enable = true;
        programs = {
          vite = {
            autostart = true;
            directory = config.dir.project;
            stderr_logfile = "/dev/stderr";
            command = "${pkgs.nodejs}/bin/node ./node_modules/vite/bin/vite.js dev --strictPort --host 127.0.0.1 --port ${toString cfg.port}";
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
      };
    };
    services.traefik = {
      routers = {
        vite = {
          service = "vite";
          rule = "Host(`vite.${config.project.domainSuffix}`)";
        };
      };
      services = {
        vite = {
          loadBalancer.servers = [
            {url = "http://127.0.0.1:${toString cfg.port}";}
          ];
        };
      };
    };
  };
}
