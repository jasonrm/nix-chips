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
      optionalString (secretEnvFiles != { }) ''
        set -o allexport
        ${concatStringsSep "\n" (
          mapAttrsToList (name: secret: ''
            if [ -f "${secret.dest}" ]; then
              source ${secret.dest}
            else
              echo "Skipped missing secret env file ${secret.dest}"
            fi
          '') secretEnvFiles
        )}
        set +o allexport
      ''
    );
  };

}
