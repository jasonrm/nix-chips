{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib; {
  imports = [
    (modulesPath + "/services/databases/mysql.nix")
  ];
  config = {
    services.mysql = {
      package = mkForce pkgs.mysql80;
      dataDir = mkForce (config.dir.data + "/mysql");
    };
  };
}
