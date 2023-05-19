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
        default = "0.0.0.0";
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
        "MEMCACHED_HOST=${
          if (cfg.host == "0.0.0.0")
          then "127.0.0.1"
          else cfg.host
        }"
        "MEMCACHED_PORT=${toString cfg.port}"
      ];
      programs.supervisord.programs.memcached = {
        # user = cfg.user;
        # group = cfg.group;
        command = "${pkgs.memcached}/bin/memcached";
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
