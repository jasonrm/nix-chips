{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.rabbitmq;
in {
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.managementPlugin.enable) {
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
