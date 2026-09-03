{
  pkgs,
  lib,
  config,
  chips,
  inputs ? {},
  ...
}:
with lib; let
  cfg = config.devShell;

  # Note: If this dies with an error like `error: cannot coerce a list to a string`
  # then you probably have an environemnt variable that isn't able to resolve due to a loop.
  # For example, MYSQL_UNIX_PORT wasn't able to be set to `${config.services.mysql.settings.mysqld.socket}`
  envFile = pkgs.writeText "chips.shell.env" (concatStringsSep "\n" cfg.environment);

  hasGenGate = cfg.generationId > 0;
  dataDirInit =
    if config.dir.project == "/dev/null"
    then ''__chips_data_dir="$PWD/.chips"''
    else ''__chips_data_dir=${escapeShellArg config.dir.data}'';

  staleGenGate = optionalString hasGenGate ''
    __chips_our_gen="${toString cfg.generationId}"
    ${dataDirInit}
    __chips_gen_file="$__chips_data_dir/.dev-shell.gen"
    if [ -f "$__chips_gen_file" ]; then
      # Accept the older multi-field marker format; only the monotonic
      # generation is relevant now that setup hooks always run.
      read -r __chips_disk_gen _ < "$__chips_gen_file" || true
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
    mkdir -p "$__chips_data_dir"
    ${optionalString (config.dir.project == "/dev/null") ''
      printf '*\n' > "$__chips_data_dir/.gitignore"
    ''}
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

    # Activation hooks populate the current process environment and must run
    # even when stale setup hooks are prevented from writing project files.
    ${cfg.activationHooks}
    ${staleGenGate}
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
        default =
          if inputs.self ? lastModified
          then max inputs.self.lastModified (chips.lastModified or 0)
          else 0;
        description = ''
          Monotonic generation marker for the devShell init script. On
          shell entry, if an older generation has stamped a newer marker
          at <dir.data>/.dev-shell.gen, its setup hooks short-circuit so a
          stale direnv load cannot overwrite files written by a newer shell.

          Setup hooks run on every accepted activation. Consequently,
          `direnv reload` always reapplies the evaluated configuration and
          recreates deleted generated files without a separate force flag.

          The marker is stored under <dir.data>, or under $PWD/.chips when
          dir.project is unset.

          Defaults to the newer of the consuming flake's lastModified
          and the nix-chips input's lastModified. When the consuming flake
          has no lastModified (for example, an explicit `path:` flake
          reference), this defaults to 0 and disables the gate: without a
          monotonic source generation, comparing against an older marker can
          incorrectly suppress a newer configuration. Set to 0 to disable the
          gate explicitly.
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

      activationHooks = mkOption {
        type = lines;
        default = "";
        description = "Shell hooks that run on every devShell activation, including when cached setup hooks are skipped.";
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
