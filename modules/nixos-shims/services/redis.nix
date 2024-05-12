{
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; {
  imports = [
    (modulesPath + "/services/databases/redis.nix")
  ];
}
