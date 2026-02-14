{
  lib,
  pkgs,
  config,
  chips,
  ...
}:
with lib; let
  inherit (chips.lib.traefik) hostRegexp;

  cfg = config.services.dynamodb;
in {
  options = with types; {
    services.dynamodb = {
      enable = mkEnableOption "enable dynamodb";

      virtualHost = mkOption {
        type = submodule (import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix");
        default = {};
        description = mdDoc ''
          Nginx configuration can be done by adapting {option}`services.nginx.virtualHosts`.
          See [](#opt-services.nginx.virtualHosts) for further information.
        '';
      };

      port = lib.mkOption {
        type = int;
        default = config.ports.dynamodb;
      };
      dataDir = lib.mkOption {
        type = path;
        default = "${config.dir.data}/dynamodb";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      dir.ensureExists = [cfg.dataDir];

      devShell.environment = [
        "AWS_ENDPOINT_URL_DYNAMODB=http://${config.project.address}:${toString cfg.port}"
        "DYNAMODB_PORT=${toString cfg.port}"
        "DYNAMODB_DOMAIN=dynamodb.${config.project.domainSuffix}"
      ];

      services.php = {
        phpEnv = {
          "AWS_ENDPOINT_URL_DYNAMODB" = "http://${config.project.address}:${toString cfg.port}";
        };
      };
      programs = {
        supervisord.programs = {
          dynamodb = {
            directory = cfg.dataDir;
            command = "${pkgs.dynamodb}/bin/dynamodb-local";
            environment = [
              "DYNAMODB_PORT=${toString cfg.port}"
              "DYNAMODB_DATA_PATH=${cfg.dataDir}"
            ];
            autostart = true;
            stderr_logfile = "/dev/stderr";
          };
        };
      };

      services.nginx.virtualHosts.dynamodb =
        cfg.virtualHost
        // {
          serverName = "dynamodb.${config.project.domainSuffix}";
          locations = {
            "/" = {
              proxyPass = "http://${config.project.address}:${toString cfg.port}";
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
          dynamodb = {
            service = "dynamodb";
            rule = hostRegexp ["dynamodb"] [config.project.domainSuffix];
          };
        };
        services = {
          dynamodb = {
            loadBalancer.servers = [{url = "http://${config.project.address}:${toString cfg.port}";}];
          };
        };
      };
    })
  ];
}
