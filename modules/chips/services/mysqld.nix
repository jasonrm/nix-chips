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
    if [ ! -d "${dataDir}" ]; then
      mkdir -p "${runDir}" "${logDir}" "${dataDir}"
      echo 'Initializing database...'
      ${cfg.package}/bin/mysqld \
        --initialize \
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
            "CREATE USER IF NOT EXISTS '${user.name}'@'localhost' IDENTIFIED BY '${user.name}';"
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

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
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
      programs.supervisord.programs.mysqld = {
        # user = cfg.user;
        # group = cfg.group;
        command = "${mysqld}/bin/mysqld";
      };
      chips.devShell.contents = [
        mysql
        mysqld
        mysqldump
      ];
    })
    {
      outputs.apps.mysql = {
        program = "${mysql}/bin/mysql";
      };
      outputs.apps.mysqld = {
        program = "${mysqld}/bin/mysqld";
      };
      outputs.apps.mysqldump = {
        program = "${mysqldump}/bin/mysqldump";
      };
    }
  ];
}
