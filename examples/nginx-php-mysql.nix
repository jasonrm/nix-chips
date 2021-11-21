{ lib, pkgs, config, ... }:
{
  imports = [ ];
  options = { };
  config = {
    dir.root = "/opt/projects/nix-chips";

    services.mysqld = {
      enable = true;
    };

    services.redis = {
      enable = true;
    };

    # services.nginx = {
    #   enable = true;
    #   servers = [
    #     ''
    #       server {
    #         listen ${toString config.ports.http};
    #         server_name _;
    #         root ${pkgs.nginx}/html;
    #       }
    #     ''
    #   ];
    # };
  };
}
