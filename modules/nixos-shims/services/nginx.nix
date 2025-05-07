{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib;
{
  imports = [ (modulesPath + "/services/web-servers/nginx/default.nix") ];
}
