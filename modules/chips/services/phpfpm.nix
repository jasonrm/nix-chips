{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption;

  cfg = config.services.phpfpm;

  toStr = value:
    if true == value
    then "yes"
    else if false == value
    then "no"
    else toString value;

  #    ${optionalString (cfg.extraConfig != null) cfg.extraConfig}
  fpmCfgFile = pool: poolOpts:
    pkgs.writeText "phpfpm-${pool}.conf" ''
      [global]
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") cfg.settings)}

      [${pool}]
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") poolOpts.settings)}
    ''
    + lib.optionalString cfg.xdebug.enable ''
      php_admin_value[xdebug.output_dir] = ${cfg.logDir}/xdebug;
    '';
  #    ${lib.concatStringsSep "\n" (mapAttrsToList (n: v: "env[${n}] = ${toStr v}") poolOpts.phpEnv)}
  #    ${optionalString (poolOpts.extraConfig != null) poolOpts.extraConfig}

  poolOpts = {name, ...}: let
    poolOpts = cfg.pools.${name};
  in {
    options = with lib.types; {
      settings = mkOption {
        type = attrsOf (oneOf [str int bool]);
        default = {};
      };
      phpPackage = mkOption {
        type = package;
        default = cfg.phpPackage;
      };
      socket = mkOption {
        type = str;
        readOnly = true;
        example = "${cfg.runDir}/<name>.sock";
      };
      user = mkOption {
        type = nullOr str;
        default = "nobody";
      };
      group = mkOption {
        type = nullOr str;
        default = "nobody";
      };
      environment = mkOption {
        type = listOf str;
        default = [];
      };
    };
    config = {
      socket = "${cfg.runDir}/${name}.sock";

      settings = lib.mapAttrs (name: lib.mkDefault) {
        inherit (poolOpts) user group;
        listen = poolOpts.socket;
        "listen.owner" = poolOpts.user;
        "listen.group" = poolOpts.group;
        "listen.mode" = 0660;
        "access.log" = "${cfg.logDir}/${name}.log";
      };
    };
  };
in {
  imports = [
  ];

  config = lib.mkIf false {
    dir.ensureExists =
      [
        cfg.runDir
        cfg.logDir
      ]
      ++ lib.optionals cfg.xdebug.enable [
        "${cfg.logDir}/xdebug"
      ];

    programs.supervisord.programs =
      lib.mapAttrs'
      (pool: poolOpts:
        lib.nameValuePair "phpfpm-${pool}" {
          command = "${poolOpts.phpPackage}/bin/php-fpm --fpm-config=${fpmCfgFile pool poolOpts}";
          environment = config.shell.environment ++ poolOpts.environment;
        })
      cfg.pools;
  };
}
