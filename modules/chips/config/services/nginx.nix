{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
with lib; {
  imports = [
    (modulesPath + "/services/web-servers/nginx/default.nix")
  ];
  config = mkIf config.services.nginx.enable {
    programs.supervisord.enable = true;
  };
}
