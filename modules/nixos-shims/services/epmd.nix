{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib; {
  imports = [
    (modulesPath + "/services/networking/epmd.nix")
  ];
}
