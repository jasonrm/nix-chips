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
      mkdir -p "${runDir}" "${logDir}" "${dataDir}"
      echo 'Initializing database...'
      ${cfg.package}/bin/mysqld \
        --initialize \
        --initialize-insecure \
        --authentication-policy="mysql_native_password" \
        ${
      if cfg.initialScript != null
      then "--init-file=${cfg.initialScript}"
      else ""
    } \
        ${mysqldOptions} \
      > /dev/null
    fi

    exec ${cfg.package}/bin/mysqld \
      --defaults-file=${configFile} \
      --init-file=${ensureFile} \
      ${mysqldOptions}
  '';

  ensureFile = pkgs.writeText "ensure.sql" ''
    ${concatMapStrings (
        database: "CREATE DATABASE IF NOT EXISTS `${database}`;"
      )
      cfg.ensureDatabases}

    ${concatMapStrings (user: (
        concatStringsSep "\n" ([
            "CREATE USER IF NOT EXISTS '${user.name}'@'localhost';"
          ]
          ++ (mapAttrsToList (
              database: permission: "GRANT ${permission} ON ${database} TO '${user.name}'@'localhost';"
            )
            user.ensurePermissions))
      ))
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
  imports = [
  ];

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
          socket = runDir + "/mysqld.sock";
          authentication-policy = "mysql_native_password";
        };
      };
    };
    programs.supervisord.programs.mysql = {
      stopwaitsecs = 60;
      startsecs = 5;
      command = "${mysqld}/bin/mysqld";
    };
    chips.devShell.contents = [
      mysql
      mysqld
      mysqldump
    ];
  };
}
