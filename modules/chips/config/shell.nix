{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.chips.devShell;

  envFile = pkgs.writeText "devShell.env" (lib.concatStringsSep "\n" cfg.environment);

  shellHook = pkgs.writeShellScriptBin "devShell.init.sh" ''
    set -o errexit
    set -o nounset
    set -o pipefail

    EXPECTED_PROJECT_DIR=$(realpath "${config.dir.project}")
    ACTUAL_PROJECT_DIR=$(realpath "$PWD")
    if [ "$EXPECTED_PROJECT_DIR" != "$ACTUAL_PROJECT_DIR" ]; then
      echo "Your devShell configuration has the wrong project directory."
      echo "Expected: $EXPECTED_PROJECT_DIR"
      echo "Actual:   $ACTUAL_PROJECT_DIR"
      exit 1
    fi

    set -a
    source ${envFile}
    set +a

    ${lib.concatStringsSep "\n" cfg.shellHooks}
  '';
in {
  imports = [
    # paths to other modules
  ];

  options = with lib.types; {
    chips.devShell = {
      enable = mkEnableOption "use shell";

      environment = mkOption {
        type = listOf str;
        default = [];
      };

      shellHooks = mkOption {
        type = listOf lines;
        default = [];
      };

      directories = mkOption {
        type = listOf str;
        default = [];
      };

      contents = mkOption {
        type = listOf package;
        default = [];
      };
    };
  };

  config = {
    outputs.devShell = pkgs.mkShell {
      buildInputs =
        cfg.contents
        ++ lib.optionals pkgs.stdenv.isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
          CoreServices
        ]);

      shellHook = "${shellHook}/bin/devShell.init.sh";
    };
  };
}
