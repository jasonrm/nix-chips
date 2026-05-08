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
    };
  };
}
