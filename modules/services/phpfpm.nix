{ lib, pkgs, config, ... }:
let
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
      options = {
        settings = lib.mkOption {
          type = with lib.types; attrsOf (oneOf [ str int bool ]);
          default = { };
        };
        phpPackage = lib.mkOption {
          type = lib.types.package;
          default = cfg.phpPackage;
        };
        socket = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          example = "${config.dir.run}/php-fpm/<name>.sock";
        };

      };
      config = {
        socket = "${config.dir.run}/php-fpm/${name}.sock";

        settings = lib.mapAttrs (name: lib.mkDefault) {
          listen = poolOpts.socket;
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
        default = { };
      };
      # user = lib.mkOption {
      #   type = with lib.types; nullOr str;
      #   default = config.default.user;
      # };
      # group = lib.mkOption {
      #   type = with lib.types; nullOr str;
      #   default = config.default.group;
      # };
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
        default = pkgs.php;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    shell.directories = [
      cfg.runDir
      cfg.logDir
    ] ++ lib.optionals cfg.xdebug.enable [
      "${cfg.logDir}/xdebug"
    ];
    # services.phpfpm.settings = {
    #   error_log = "${cfg.logDir}/daemon.error";
    #   daemonize = false;
    # };
    programs.supervisord.programs = lib.mapAttrs'
      (pool: poolOpts: lib.nameValuePair "phpfpm-${pool}" {
        # user = cfg.user;
        # group = cfg.group;
        command =
          let
            cfgFile = fpmCfgFile pool poolOpts;
          in
          "${poolOpts.phpPackage}/bin/php-fpm --fpm-config=${cfgFile}";
      })
      cfg.pools;
  };
}
