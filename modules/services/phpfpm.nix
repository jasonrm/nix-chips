{ lib, pkgs, config, ... }:
let
  inherit (lib) mkOption;

  cfg = config.services.phpfpm;

  toStr = value:
    if true == value then "yes"
    else if false == value then "no"
    else toString value;

  #    ${optionalString (cfg.extraConfig != null) cfg.extraConfig}
  fpmCfgFile = pool: poolOpts: pkgs.writeText "phpfpm-${pool}.conf" ''
    [global]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") cfg.settings)}

    [${pool}]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") poolOpts.settings)}
  '' + lib.optionalString cfg.xdebug.enable ''
    php_admin_value[xdebug.output_dir] = ${cfg.logDir}/xdebug;
  '';
  #    ${lib.concatStringsSep "\n" (mapAttrsToList (n: v: "env[${n}] = ${toStr v}") poolOpts.phpEnv)}
  #    ${optionalString (poolOpts.extraConfig != null) poolOpts.extraConfig}

  poolOpts = { name, ... }:
    let
      poolOpts = cfg.pools.${name};
    in
    {
      options = with lib.types; {
        settings = mkOption {
          type = attrsOf (oneOf [ str int bool ]);
          default = { };
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
in
{
  imports = [
  ];

  options = {
    services.phpfpm = {
      enable = lib.mkEnableOption "enable php-fpm";

      xdebug = {
        enable = lib.mkEnableOption "enable xdebug";
      };

      settings = lib.mkOption {
        type = with lib.types; attrsOf (oneOf [ str int bool ]);
        default = {
          daemonize = false;
          error_log = "${cfg.logDir}/error.log";
        };
      };

      runDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.dir.run}/php-fpm";
      };

      logDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.dir.log}/php-fpm";
      };

      pools = lib.mkOption {
        default = { };
        type = with lib.types; attrsOf (submodule poolOpts);
      };

      phpPackage = lib.mkOption {
        type = lib.types.package;
        default = config.programs.php.env;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dir.ensureExists = [
      cfg.runDir
      cfg.logDir
    ] ++ lib.optionals cfg.xdebug.enable [
      "${cfg.logDir}/xdebug"
    ];

    programs.supervisord.programs = lib.mapAttrs'
      (pool: poolOpts: lib.nameValuePair "phpfpm-${pool}" {
        command = "${poolOpts.phpPackage}/bin/php-fpm --fpm-config=${fpmCfgFile pool poolOpts}";
      })
      cfg.pools;
  };
}
