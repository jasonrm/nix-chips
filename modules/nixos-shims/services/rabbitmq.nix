{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib;
{
  imports = [ (modulesPath + "/services/amqp/rabbitmq.nix") ];
}
