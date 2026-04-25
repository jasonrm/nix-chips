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
  in
    pkgs.writeText "phpfpm-${pool}.conf" ''
      [global]
      ${concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") cfg.settings)}

      [${pool}]
      ${concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") poolSettings)}
      ${concatStringsSep "\n" (mapAttrsToList (n: v: "env[${n}] = ${toStr v}") poolOpts.phpEnv)}
      ${optionalString (poolOpts.extraConfig != null) poolOpts.extraConfig}
    '';
  socketDirs = lib.unique (
    lib.mapAttrsToList (_: opts: builtins.dirOf opts.listen) (
      lib.filterAttrs (_: opts: lib.hasPrefix "/" (opts.listen or "")) cfg.pools
    )
  );
in {
  imports = [];

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
