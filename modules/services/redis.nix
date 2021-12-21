{ lib, pkgs, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.services.redis;

  configFile = pkgs.writeText "redis.conf" ''
    bind ${cfg.host}
    port ${toString cfg.port}
    timeout 0
    daemonize no
    supervised no
    loglevel notice
    logfile "${cfg.logDir}/redis.log"
    databases 16
    save 900 1
    save 300 10
    save 60 10000
    stop-writes-on-bgsave-error no
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir "${cfg.dataDir}"

    loadmodule ${pkgs.staging.redis-cell}/lib/${if pkgs.stdenv.isDarwin then "libredis_cell.dylib" else "libredis_cell.so"}
  '';

  redis-cli = pkgs.writeShellScriptBin "redis-cli" ''
    exec ${pkgs.redis}/bin/redis-cli -h $REDIS_HOST -p $REDIS_PORT $@
  '';
in
{
  options = with types; {
    services.redis = {
      enable = lib.mkEnableOption "enable redis";

      user = mkOption {
        type = nullOr str;
        default = config.default.user;
      };
      group = mkOption {
        type = nullOr str;
        default = config.default.group;
      };

      runDir = mkOption {
        type = str;
        default = "${config.dir.run}/redis";
      };
      logDir = mkOption {
        type = str;
        default = "${config.dir.log}/redis";
      };
      dataDir = mkOption {
        type = str;
        default = "${config.dir.lib}/redis";
      };

      host = mkOption {
        type = str;
        default = "0.0.0.0";
      };
      port = mkOption {
        type = int;
        default = config.ports.redis;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dir.ensureExists = [
      cfg.runDir
      cfg.logDir
      cfg.dataDir
    ];
    shell.contents = [
      redis-cli
    ];
    shell.environment = [
      "REDIS_HOST=${if (cfg.host == "0.0.0.0") then "127.0.0.1" else cfg.host}"
      "REDIS_PORT=${toString cfg.port}"
    ];
    programs.supervisord.programs.redis = {
      command = "${pkgs.redis}/bin/redis-server ${configFile}";
    };
  };
}
