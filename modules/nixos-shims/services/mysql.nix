{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib; {
  imports = [(modulesPath + "/services/databases/mysql.nix")];
  config = {
    services.mysql = {
      package = mkDefault pkgs.mysql80;
      dataDir = mkForce (config.dir.data + "/mysql");
    };
    systemd.services.mysql = {
      # work around https://github.com/NixOS/nixpkgs/blob/5e2a59a5b1a82f89f2c7e598302a9cacebb72a67/nixos/modules/services/databases/mysql.nix#L526
      path = mkForce [];
    };
  };
}
