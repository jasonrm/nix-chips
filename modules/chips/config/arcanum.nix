{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.arcanum;
  filesWithDest = filterAttrs (n: secret: secret.dest != null) cfg.files;
  secretEnvFiles = filterAttrs (n: secret: secret.dest != null && secret.isEnvFile == true) cfg.files;
  editFiles =
    mapAttrsToList (name: secret: {
      inherit (secret) source dest;
    })
    filesWithDest;
in {
  config = mkIf cfg.enable {
    devShell.contents = [pkgs.arcanum];
    devShell.environment = optional (editFiles != []) "ARCANUM_EDIT_FILES=${escapeShellArg (builtins.toJSON editFiles)}";

    devShell.activationHooks = mkOrder 751 (
      optionalString (secretEnvFiles != {}) ''
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
          '')
          secretEnvFiles
        )}
        set +o allexport
      ''
    );
  };
}
