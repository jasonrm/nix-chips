{
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; {
  imports = [(modulesPath + "/services/networking/haproxy.nix")];
}
