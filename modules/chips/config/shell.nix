{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.devShell;

  # Note: If this dies with an error like `error: cannot coerce a list to a string`
  # then you probably have an environemnt variable that isn't able to resolve due to a loop.
  # For example, MYSQL_UNIX_PORT wasn't able to be set to `${config.services.mysql.settings.mysqld.socket}`
  envFile = pkgs.writeText "chips.shell.env" (concatStringsSep "\n" cfg.environment);

  shellHook = pkgs.writeShellScriptBin "devShell.init.sh" ''
    set -o errexit
    set -o nounset
    set -o pipefail

    if [ "${toString cfg.requireProjectDirectory}" == "true" ]; then
      EXPECTED_PROJECT_DIR=$(realpath "${config.dir.project}")
      ACTUAL_PROJECT_DIR=$(realpath "$PWD")
      if [ "$EXPECTED_PROJECT_DIR" != "$ACTUAL_PROJECT_DIR" ]; then
        echo "Your devShell configuration has the wrong project directory."
        echo "Expected: $EXPECTED_PROJECT_DIR"
        echo "Actual:   $ACTUAL_PROJECT_DIR"
        exit 1
      fi
    fi

    ${cfg.shellHooks}
  '';
in {
  imports = [
    # paths to other modules
  ];

  options = with lib.types; {
    devShell = {
      enable = mkEnableOption "Enable devShell";

      requireProjectDirectory = mkEnableOption "Require the project directory to be set";

      environment = mkOption {
        type = listOf str;
        default = [];
      };

      shellHooks = mkOption {
        type = lines;
        default = "";
      };

      directories = mkOption {
        type = listOf str;
        default = [];
      };

      nativeBuildInputs = mkOption {
        type = listOf package;
        default = [];
      };

      contents = mkOption {
        type = listOf package;
        default = [];
      };

      output = mkOption {
        readOnly = true;
        type = package;
      };
    };
  };

  config = {
    devShell.output = pkgs.mkShell {
      nativeBuildInputs = cfg.nativeBuildInputs;
      buildInputs =
        cfg.contents
        ++ lib.optionals pkgs.stdenv.isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
          CoreServices
        ]);

      shellHook = ''
        export CHIPS_ENV_FILE=${envFile}
        ${shellHook}/bin/devShell.init.sh
      '';
    };
  };
}
