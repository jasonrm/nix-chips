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

  # Any config change that affects the hooks (secrets, symlink targets,
  # generated files, ...) changes the store paths embedded in them, and
  # therefore this hash.
  hooksHash = builtins.hashString "sha256" cfg.shellHooks;

  genGate = optionalString hasGenGate ''
    __chips_our_gen="${toString cfg.generationId}"
    __chips_our_hash="${hooksHash}"
    __chips_gen_file="${config.dir.data}/.dev-shell.gen"
    # Hooks write $PWD-relative outputs (Taskfile.yml, lefthook config, ...),
    # so the completed-run marker is kept per entry directory; the shared
    # .dev-shell.gen file only guards against stale (older-generation) loads.
    __chips_pwd_gen_file="${config.dir.data}/.dev-shell.gen.d/$(printf '%s' "$PWD" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -c1-16)"
    if [ -f "$__chips_gen_file" ]; then
      read -r __chips_disk_gen __chips_disk_hash < "$__chips_gen_file" || true
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
    if [ -f "$__chips_pwd_gen_file" ]; then
      read -r __chips_disk_gen __chips_disk_hash < "$__chips_pwd_gen_file" || true
      case "$__chips_disk_gen" in
        ""|*[!0-9]*) ;;
        *)
          if [ "$__chips_disk_gen" -eq "$__chips_our_gen" ] \
            && [ "''${__chips_disk_hash:-}" = "$__chips_our_hash" ] \
            && [ -z "''${CHIPS_DEV_SHELL_FORCE:-}" ]; then
            # This exact configuration already completed in this directory.
            return 0 2>/dev/null || exit 0
          fi
          ;;
      esac
    fi
  '';

  genStamp = optionalString hasGenGate ''
    mkdir -p "$(dirname "$__chips_pwd_gen_file")"
    printf '%s %s\n' "$__chips_our_gen" "$__chips_our_hash" > "$__chips_gen_file"
    printf '%s %s\n' "$__chips_our_gen" "$__chips_our_hash" > "$__chips_pwd_gen_file"
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

          Completed runs are additionally stamped per entry directory
          under <dir.data>/.dev-shell.gen.d/ (keyed by a hash of $PWD),
          because hooks write $PWD-relative outputs (Taskfile.yml,
          lefthook config, ...). A re-entry whose generation AND hook
          hash match the marker for the same directory skips the hooks
          entirely (fast path); entering the shell from a directory
          that has not completed this exact configuration re-runs them.
          The hooks embed the store paths of everything they produce,
          so any flake/config/secret change re-runs them automatically.
          Tradeoff: hook *outputs* deleted by hand (a decrypted secret,
          a symlink) are not recreated until forced.

          Defaults to the nix-chips input's lastModified. Set to 0 to
          disable the gate. Override with your own flake's
          self.lastModified to also bump on local source changes.

          To force re-run: CHIPS_DEV_SHELL_FORCE=1 direnv reload
          (or delete the markers: rm -r <dir.data>/.dev-shell.gen*).

          Note: two shells sharing one dir.data (e.g. per-host variants)
          entered from the same directory write the same marker and will
          re-run hooks when switching between them; harmless, just not
          skipped.
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
