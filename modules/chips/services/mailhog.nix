{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.mailhog;
  serviceAddress =
    if (cfg.bindAddress == "0.0.0.0")
    then "127.0.0.1"
    else cfg.bindAddress;
in {
  options = {
    services.mailhog = {
      enable = lib.mkEnableOption "enable mailhog";
      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
      };
      smtpPort = lib.mkOption {
        type = lib.types.int;
        default = config.ports.mailhogSmtp;
      };
      httpPort = lib.mkOption {
        type = lib.types.int;
        default = config.ports.mailhogHttp;
      };
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "mailhog.test";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      devShell.environment = [
        "MAIL_HOST=${serviceAddress}"
        "MAIL_PORT=${toString cfg.smtpPort}"
      ];
      services.traefik = {
        routers.mailhog = {
          entryPoints = ["http"];
          service = "mailhog";
          rule = "HostRegexp(`mailhog.${config.services.traefik.domain}`)";
        };
        services.mailhog = {
          loadBalancer.servers = [
            {url = "http://${serviceAddress}${":"}${toString cfg.httpPort}";}
          ];
        };
      };
      programs.supervisord.programs.mailhog = {
        command = ''
          ${pkgs.mailhog}/bin/MailHog \
            --hostname=${cfg.hostname} \
            --smtp-bind-addr=${cfg.bindAddress}:${toString cfg.smtpPort} \
            --api-bind-addr=${cfg.bindAddress}:${toString cfg.httpPort} \
            --ui-bind-addr=${cfg.bindAddress}:${toString cfg.httpPort}
        '';
      };
    })
  ];
}
