{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib; let
  cfg = config.devShell;

  # Note: If this dies with an error like `error: cannot coerce a list to a string`
  # then you probably have an environemnt variable that isn't able to resolve due to a loop.
  # For example, MYSQL_UNIX_PORT wasn't able to be set to `${config.services.mysql.settings.mysqld.socket}`
  envFile = pkgs.writeText "chips.shell.env" (concatStringsSep "\n" cfg.environment);

  hasGenGate = cfg.generationId > 0 && config.dir.project != "/dev/null";

  genGate = optionalString hasGenGate ''
    __chips_our_gen="${toString cfg.generationId}"
    __chips_gen_file="${config.dir.data}/.dev-shell.gen"
    if [ -f "$__chips_gen_file" ]; then
      __chips_disk_gen=$(cat "$__chips_gen_file" 2>/dev/null || true)
      case "$__chips_disk_gen" in
        ""|*[!0-9]*) ;;
        *)
          if [ "$__chips_disk_gen" -gt "$__chips_our_gen" ]; then
            echo "nix-chips: skipping stale devShell setup (gen=$__chips_our_gen < disk=$__chips_disk_gen)" >&2
            return 0 2>/dev/null || exit 0
          fi
          ;;
      esac
    fi
  '';

  genStamp = optionalString hasGenGate ''
    mkdir -p "$(dirname "$__chips_gen_file")"
    printf '%s\n' "$__chips_our_gen" > "$__chips_gen_file"
  '';

  shellHook = pkgs.writeShellScriptBin "dev-shell.init.sh" ''
    set -o errexit
    set -o nounset
    set -o pipefail

    if [ "${boolToString cfg.requireProjectDirectory}" == "true" ]; then
      EXPECTED_PROJECT_DIR=$(realpath "${config.dir.project}")
      ACTUAL_PROJECT_DIR=$(realpath "$PWD")
      case "$ACTUAL_PROJECT_DIR/" in
        "$EXPECTED_PROJECT_DIR"/*) ;;
        *)
          echo "Your devShell configuration has the wrong project directory."
          echo "Expected: $EXPECTED_PROJECT_DIR (or a subdirectory)"
          echo "Actual:   $ACTUAL_PROJECT_DIR"
          return 1 2>/dev/null || exit 1
          ;;
      esac
    fi

    ${genGate}
    ${cfg.shellHooks}
    ${genStamp}
  '';
in {
  imports = [
    # paths to other modules
  ];

  options = with lib.types; {
    devShell = {
      enable = mkEnableOption "Enable Developer Shell";

      requireProjectDirectory = mkEnableOption "Require the project directory to be set";

      generationId = mkOption {
        type = int;
        default = chips.lastModified or 0;
        description = ''
          Monotonic generation marker for the devShell init script. On
          shell entry, if an older generation has stamped a newer marker
          at <dir.data>/.dev-shell.gen, the entire init hook short-
          circuits — stale direnv loads no longer overwrite files
          (decrypted secrets, symlinks, generated configs, etc.) written
          by a newer shell.

          Defaults to the nix-chips input's lastModified. Set to 0 to
          disable the gate. Override with your own flake's
          self.lastModified to also bump on local source changes.

          To force re-run, delete the marker: rm <dir.data>/.dev-shell.gen
        '';
      };

      environment = mkOption {
        type = listOf str;
        default = [];
      };

      envFiles = mkOption {
        type = listOf path;
        default = [];
      };

      stdenv = mkOption {
        type = package;
        default = cfg.pkgs.stdenv;
      };

      pkgs = mkOption {
        type = attrs;
        default = pkgs;
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
    devShell.output = pkgs.mkShell.override {inherit (cfg) stdenv;} {
      nativeBuildInputs = cfg.nativeBuildInputs;
      buildInputs = cfg.contents;

      shellHook = ''
        set -o allexport
        source ${envFile}
        set +o allexport
        source ${shellHook}/bin/dev-shell.init.sh
      '';
    };
  };
}
