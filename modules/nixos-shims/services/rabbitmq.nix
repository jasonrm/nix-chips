{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib; {
  imports = [(modulesPath + "/services/amqp/rabbitmq.nix")];
  config = mkIf config.services.rabbitmq.enable {
    services.rabbitmq = {
      dataDir = mkForce (config.dir.data + "/rabbitmq");
      managementPlugin.enable = mkDefault true;
      configItems = mkIf config.services.rabbitmq.managementPlugin.enable {
        "management_agent.disable_metrics_collector" = mkDefault "true";
        "total_memory_available_override_value" = mkDefault "4GB";
      };
    };
    systemd.services.rabbitmq.path = [pkgs.lsof];
  };
}
