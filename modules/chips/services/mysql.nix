{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  format = pkgs.formats.ini {listsAsDuplicateKeys = true;};

  cfg = config.services.mysql;
  runDir = cfg.dataDir + "/run";
  logDir = cfg.dataDir + "/log";
  dataDir = cfg.dataDir + "/data";

  mysqldOptions = "--datadir=${dataDir} --basedir=${cfg.package}";

  configFile = format.generate "my.cnf" cfg.settings;

  mysqld = pkgs.writeShellScriptBin "mysqld" ''
    echo "Initializing MySQL..."
    if [ ! -d "${dataDir}" ]; then
      mkdir -p "${runDir}" "${logDir}" "${dataDir}" "${config.services.mysql.settings.mysqld.log_bin}" "${config.services.mysql.settings.mysqld.relay_log}" "${config.services.mysql.settings.mysqld.innodb_log_group_home_dir}"
      echo 'Initializing database...'
      ${cfg.package}/bin/mysqld \
        --defaults-file=${configFile} \
        --log-bin=${config.services.mysql.settings.mysqld.log_bin} \
        --relay-log=${config.services.mysql.settings.mysqld.relay_log} \
        --innodb-log-group-home-dir=${config.services.mysql.settings.mysqld.innodb_log_group_home_dir} \
        --initialize \
        --initialize-insecure \
        ${
      if cfg.initialScript != null
      then "--init-file=${cfg.initialScript}"
      else ""
    } \
        ${mysqldOptions}
    fi

    exec ${cfg.package}/bin/mysqld \
      --defaults-file=${configFile} \
      --init-file=${ensureFile} \
      ${mysqldOptions}
  '';

  ensureFile = pkgs.writeText "ensure.sql" ''
    ${concatMapStrings (database: "CREATE DATABASE IF NOT EXISTS `${database}`;") cfg.ensureDatabases}

    ${concatMapStrings (
        user: (concatStringsSep "\n" (
          [
            "CREATE USER IF NOT EXISTS '${user.name}'@'localhost';"
          ]
          ++ (mapAttrsToList (
              database: permission: "GRANT ${permission} ON ${database} TO '${user.name}'@'localhost';"
            )
            user.ensurePermissions)
        ))
      )
      cfg.ensureUsers}
  '';

  mysql = pkgs.writeShellScriptBin "mysql" ''
    exec ${cfg.package}/bin/mysql \
      --defaults-file=${configFile} \
      $@
  '';

  mysqldump = pkgs.writeShellScriptBin "mysqldump" ''
    exec ${cfg.package}/bin/mysqldump \
      --defaults-file=${configFile} \
      $@
  '';
in {
  imports = [];

  config = lib.mkIf cfg.enable {
    services.mysql = {
      settings = {
        mysql = {
          socket = runDir + "/mysqld.sock";
        };
        mysqldump = {
          socket = runDir + "/mysqld.sock";
        };
        mysqld = {
          tls_version = "";
          mysqlx = 0;
          socket = "${runDir}/mysqld.sock";
          log_bin = "${logDir}/binlog";
          relay_log = "${logDir}/relaylog";
          innodb_log_group_home_dir = "${logDir}";
        };
      };
    };
    programs.supervisord.programs.mysql = {
      stopwaitsecs = 60;
      startsecs = 5;
      command = "${mysqld}/bin/mysqld";
    };
    devShell = {
      environment = [
        "MYSQL_HOST=localhost"
        "MYSQL_UNIX_PORT=${runDir}/mysqld.sock"
      ];
      contents = [
        mysql
        mysqld
        mysqldump
      ];
    };
  };
}
