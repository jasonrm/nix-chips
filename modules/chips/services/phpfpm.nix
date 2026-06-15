{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.services.phpfpm;

  toStr = value:
    if true == value
    then "yes"
    else if false == value
    then "no"
    else toString value;

  fpmCfgFile = pool: poolOpts: let
    poolSettings = filterAttrs (n: v: v != "") poolOpts.settings;
    poolEnv = (poolOpts.phpEnv or {}) // cfg.extraPhpEnv;
  in
    pkgs.writeText "phpfpm-${pool}.conf" ''
      [global]
      ${concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") cfg.settings)}

      [${pool}]
      ${concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") poolSettings)}
      ${concatStringsSep "\n" (mapAttrsToList (n: v: "env[${n}] = ${toStr v}") poolEnv)}
      ${optionalString (poolOpts.extraConfig != null) poolOpts.extraConfig}
    '';
  socketDirs = lib.unique (
    lib.mapAttrsToList (_: opts: builtins.dirOf opts.listen) (
      lib.filterAttrs (_: opts: lib.hasPrefix "/" (opts.listen or "")) cfg.pools
    )
  );
in {
  imports = [];

  options.services.phpfpm.extraPhpEnv = mkOption {
    type = types.attrsOf (types.oneOf [types.str types.int types.bool]);
    default = {};
    description = "Environment variables merged into every php-fpm pool configuration.";
  };

  options.services.phpfpm.pools = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        user = mkOption {
          type = types.str;
          default = "";
        };
        group = mkOption {
          type = types.str;
          default = "";
        };
      };
    });
  };

  config = mkIf (cfg.pools != {}) {
    dir.ensureExists = socketDirs;

    programs.supervisord.programs =
      mapAttrs' (
        pool: poolOpts:
          nameValuePair "phpfpm-${pool}" {
            command = "${poolOpts.phpPackage}/bin/php-fpm --fpm-config ${fpmCfgFile pool poolOpts}";
          }
      )
      cfg.pools;
  };
}
