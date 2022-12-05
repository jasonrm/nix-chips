{
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [];
  options = {};
  config = {
    dir.root = "/opt/projects/nix-chips";

    # services.mysqld = {
    #   enable = true;
    # };

    # services.redis = {
    #   enable = true;
    # };

    programs.supervisord.enable = true;

    services.tomcat = {
      enable = true;
      package = pkgs.tomcat9;
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
