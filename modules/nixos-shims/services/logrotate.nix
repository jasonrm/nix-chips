{
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; {
  imports = [
    (modulesPath + "/services/logging/logrotate.nix")
  ];
  config = {
    services.logrotate.enable = false;
  };
}
