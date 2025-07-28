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
              if source ${secret.dest} 2>/dev/null; then
                echo "Loaded secret env file ${secret.dest}"
              else
                echo "Warning: Failed to source secret env file ${secret.dest}" >&2
              fi
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
