{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.memcached;
in {
  options = {
    services.memcached = {
      enable = lib.mkEnableOption "enable memcached";
      host = lib.mkOption {
        type = lib.types.str;
        default = config.project.address;
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = config.ports.memcached;
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      devShell.environment = [
        "MEMCACHED_HOST=${cfg.host}"
        "MEMCACHED_PORT=${toString cfg.port}"
      ];
      programs.supervisord.programs.memcached = {
        # user = cfg.user;
        # group = cfg.group;
        command = "${pkgs.memcached}/bin/memcached -l ${cfg.host} -p ${toString cfg.port}";
      };
    })
    {
      #      outputs.apps.memcached = {
      #        # user = cfg.user;
      #        # group = cfg.group;
      #        program = "${pkgs.memcached}/bin/memcached";
      #      };
    }
  ];
}
