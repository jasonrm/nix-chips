{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.rabbitmq;
  haproxyEnabled = config.services.haproxy.enable;
  hasStomp = builtins.elem "rabbitmq_web_stomp" cfg.plugins;
  domain = config.project.domainSuffix;
  stompPort = 15674;
  stompHost = "stomp.${domain}";
  mgmtHost = "rabbitmq.${domain}";
in {
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      devShell.environment =
        [
          "RABBITMQ_HOST=${cfg.listenAddress}"
          "RABBITMQ_PORT=${toString cfg.port}"
        ]
        ++ lib.optionals hasStomp [
          "RABBITMQ_STOMP_HOST=${
            if haproxyEnabled
            then stompHost
            else cfg.listenAddress
          }"
          "RABBITMQ_STOMP_PORT=${toString (
            if haproxyEnabled
            then config.ports.https
            else stompPort
          )}"
        ]
        ++ lib.optionals cfg.managementPlugin.enable [
          "RABBITMQ_MANAGEMENT_HOST=${
            if haproxyEnabled
            then mgmtHost
            else cfg.listenAddress
          }"
          "RABBITMQ_MANAGEMENT_PORT=${toString (
            if haproxyEnabled
            then config.ports.https
            else cfg.managementPlugin.port
          )}"
        ];
    })
    (lib.mkIf (cfg.enable && cfg.managementPlugin.enable) {
      services.traefik = {
        routers = {
          rabbitmq = {
            service = "rabbitmq";
            rule = "Host(`${mgmtHost}`)";
          };
        };
        services = {
          rabbitmq = {
            loadBalancer.servers = [{url = "http://${cfg.listenAddress}:${toString cfg.managementPlugin.port}";}];
          };
        };
      };
    })
    (lib.mkIf (cfg.enable && haproxyEnabled && cfg.managementPlugin.enable) {
      services.haproxy = {
        virtualHosts.rabbitmq-mgmt = {
          host = mgmtHost;
          backend = "rabbitmq-mgmt";
        };
        backends.rabbitmq-mgmt.servers = [
          {
            name = "mgmt";
            address = "${cfg.listenAddress}:${toString cfg.managementPlugin.port}";
          }
        ];
      };
    })
    (lib.mkIf (cfg.enable && haproxyEnabled && hasStomp) {
      services.haproxy = {
        virtualHosts.rabbitmq-stomp = {
          host = stompHost;
          backend = "rabbitmq-stomp";
        };
        backends.rabbitmq-stomp.servers = [
          {
            name = "stomp";
            address = "${cfg.listenAddress}:${toString stompPort}";
          }
        ];
      };
    })
  ];
}
