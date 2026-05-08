{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.rabbitmq;
in {
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      devShell.environment = [
        "RABBITMQ_HOST=${cfg.listenAddress}"
        "RABBITMQ_PORT=${toString cfg.port}"
      ];
    })
    (lib.mkIf (cfg.enable && cfg.managementPlugin.enable) {
      devShell.environment = [
        "RABBITMQ_MANAGEMENT_PORT=${toString cfg.managementPlugin.port}"
      ];
      services.traefik = {
        routers = {
          rabbitmq = {
            service = "rabbitmq";
            rule = "Host(`rabbitmq.localhost`)";
          };
        };
        services = {
          rabbitmq = {
            loadBalancer.servers = [{url = "http://${config.project.address}:${toString cfg.managementPlugin.port}";}];
          };
        };
      };
    })
  ];
}
