{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.arcanum;
  secretEnvFiles = filterAttrs (n: secret: secret.dest != null && secret.isEnvFile == true) cfg.files;
in
{
  config = mkIf cfg.enable {
    devShell.contents = [ pkgs.arcanum ];

    devShell.shellHooks = mkOrder 751 (
      concatStringsSep "\n" (
        mapAttrsToList (name: secret: ''
          set -o allexport
          echo "Loading ${secret.dest}"
          source ${secret.dest}
          set +o allexport
        '') secretEnvFiles
      )
    );
  };

}
