{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib; {
  imports = [
    (modulesPath + "/services/web-servers/minio.nix")
  ];
  config = {
    services.minio = {
      dataDir = mkForce [
        (config.dir.data + "/minio/data")
      ];
      configDir = mkForce (config.dir.data + "/minio/config");
    };
  };
}
