{ lib, pkgs, config, ... }:
let
  inherit (lib) mkOption;

  cfg = config.services.mysqld;

  envHost = if (cfg.host == "0.0.0.0") then "127.0.0.1" else cfg.host;

  command = pkgs.writeShellScriptBin "mysqld" ''
    if [ ! -d "${cfg.dataDir}/data" ]; then
      echo 'Initializing database...'
      ${cfg.pkg}/bin/mysqld --initialize --initialize-insecure --datadir "${cfg.dataDir}/data" --default-authentication-plugin=mysql_native_password >/dev/null
    fi

    exec ${cfg.pkg}/bin/mysqld \
      --datadir="${cfg.dataDir}/data" \
      --general_log=ON \
      --log_output=TABLE \
      --log_queries_not_using_indexes=ON \
      --long_query_time=1 \
      --port=${toString cfg.port} \
      --slow_query_log=ON \
      --socket="${cfg.socket}/mysqld.sock"
  '';

  createdb = pkgs.writeText "createdb.sql" ''
    DROP DATABASE IF EXISTS ${cfg.database};
    CREATE DATABASE ${cfg.database};

    CREATE USER IF NOT EXISTS '${cfg.mysql_user}'@'%' IDENTIFIED BY '${cfg.password}';
    GRANT ALL ON *.* TO '${cfg.mysql_user}'@'%';

    CREATE USER IF NOT EXISTS 'slowlog'@'%' IDENTIFIED BY '4995C7F26CC3' WITH MAX_USER_CONNECTIONS 10;
    GRANT SELECT, DROP ON mysql.* TO 'slowlog'@'%';

    FLUSH PRIVILEGES;
  '';

  mysql = pkgs.writeShellScriptBin "mysql" ''
    exec ${cfg.pkg}/bin/mysql -h${envHost} -u${cfg.mysql_user} -p${cfg.password} -P${toString cfg.port} --protocol tcp $@
  '';

  mysqldump = pkgs.writeShellScriptBin "mysqldump" ''
    exec ${cfg.pkg}/bin/mysqldump -h${envHost} -u${cfg.mysql_user} -p${cfg.password} -P${toString cfg.port} --protocol tcp $@
  '';

  mysqlsnap = pkgs.writeShellScriptBin "mysqlsnap" ''
    OUT_PATH="''${2:-${cfg.dataDir}/snap.sql}"
    if [[ "$1" == "snap" ]]; then
      ${mysqldump}/bin/mysqldump ${cfg.database} > $OUT_PATH || exit 1
      echo
      echo "wrote: $OUT_PATH"
    elif [[ "$1" == "rollback" ]]; then
      cat $OUT_PATH | ${mysql}/bin/mysql ${cfg.database} || exit 1
      echo
      echo "restored: $OUT_PATH"
    else
      echo
      PROG=$(basename $0)
      echo "Usage: $PROG [snap|rollback] [filename]"
      echo "  snap     : creates a snapshot of the ${cfg.database} database"
      echo "  rollback : rollback to the snapshot of the ${cfg.database} database"
      echo
      echo "  filename : ${cfg.dataDir}/snap.sql"
    fi
  '';

  mysqlinit = pkgs.writeShellScriptBin "mysqlinit" ''
    counter=0
    while true; do
        if [[ "$counter" -gt 30 ]]; then
            echo "MySQL check failed"
            exit 1
        fi
        echo "Checking ${envHost}:${toString cfg.port}"
        if ${pkgs.netcat-gnu}/bin/nc -z -v -w 5 ${envHost} ${toString cfg.port}; then echo "OK"; break; fi
        echo "Waiting on MySQL"
        sleep 1
        counter=$((counter+1))
    done

    cat "${createdb}" | ${cfg.pkg}/bin/mysql -h${envHost} -uroot --skip-password -P${toString cfg.port} --protocol tcp || true
  '';
in
{
  imports = [
  ];

  options = {
    services.mysqld = with lib.types; {
      enable = lib.mkEnableOption "enable mysqld";

      pkg = mkOption {
        type = package;
        default = pkgs.mysql80;
      };

      runDir = mkOption {
        type = str;
        default = "${config.dir.run}/mysql";
      };
      logDir = mkOption {
        type = str;
        default = "${config.dir.log}/mysql";
      };
      dataDir = mkOption {
        type = str;
        default = "${config.dir.lib}/mysql";
      };

      socket = mkOption {
        type = str;
        readOnly = true;
        default = "${config.dir.run}/mysql/mysql.sock";
      };

      host = mkOption {
        type = str;
        default = "0.0.0.0";
      };
      port = mkOption {
        type = int;
        readOnly = true;
        default = config.ports.mysql;
      };
      database = mkOption {
        type = str;
        default = "unnamed";
      };
      mysql_user = mkOption {
        type = str;
        default = "root";
      };
      password = mkOption {
        type = str;
        default = "";
      };

    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      dir.ensureExists = [
        cfg.runDir
        cfg.logDir
        cfg.dataDir
      ];
      shell.environment = [
        "MYSQL_HOST=${envHost}"
        "MYSQL_DATABASE=${cfg.database}"
        "MYSQL_USER=${cfg.mysql_user}"
        "MYSQL_PWD=${cfg.password}"
        "MYSQL_TCP_PORT=${toString cfg.port}"
        "MYSQL_SOCKET=${cfg.runDir}/mysqld.sock"
        "MYSQL_DSN=${cfg.mysql_user}:${cfg.password}@tcp(${envHost}:${toString cfg.port})/${cfg.database}"
      ];
      shell.contents = [
        mysql
      ];
      programs.supervisord.programs.mysqld = {
        # user = cfg.user;
        # group = cfg.group;
        command = "${command}/bin/mysqld";
      };
    })
    (lib.mkIf cfg.enable {
      shell.contents = [
        mysqldump
        mysqlinit
        mysqlsnap
      ];
    })
  ];
}
