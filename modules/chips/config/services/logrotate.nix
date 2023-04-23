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
}
