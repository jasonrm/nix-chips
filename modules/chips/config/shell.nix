{
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

  coreutils = "${pkgs.coreutils}/bin";
  isPwdData = config.dir.project == "/dev/null";
  dataDirInit =
    if isPwdData
    then ''__chips_data_dir="$PWD/.chips"''
    else ''__chips_data_dir=${escapeShellArg config.dir.data}'';

  # Any config change that affects the setup hooks (secrets, symlink targets,
  # generated files, ...) changes the store paths embedded in them, and
  # therefore this hash.
  hooksHash = builtins.hashString "sha256" cfg.shellHooks;

  # A generation is one fresh nix-direnv evaluation. nix-direnv deletes and
  # recreates its profile rc on every renewal (`direnv reload`, or flake.nix /
  # flake.lock newer than the cache) but only touches the existing file on
  # cached entries, so the rc's birth time identifies the generation this
  # script belongs to. Setup hooks run once per generation per entry directory
  # (hooks write $PWD-relative outputs such as Taskfile.yml), and a cached
  # shell that is older than a generation already applied elsewhere is refused
  # so it cannot overwrite newer files. Concurrent activations are serialized
  # across the complete check/run/stamp transaction. Without a profile rc (nix
  # develop, stock direnv) every activation is its own generation and hooks run
  # once they acquire the lock.
  setupGate = ''
    ${dataDirInit}
    __chips_hash=${hooksHash}
    __chips_rc=""

    # The generation markers are a cache, not a mutex: two activations can
    # otherwise both observe a stale marker and concurrently modify the same
    # project files. Keep the descriptor open until setup has been stamped;
    # flock releases it automatically if an activation exits or is killed.
    ${coreutils}/mkdir -p "$__chips_data_dir"
    exec {__chips_lock_fd}>"$__chips_data_dir/.dev-shell.lock"
    ${pkgs.flock}/bin/flock -x "$__chips_lock_fd"
    # nix-direnv evals the profile rc inside _nix_import_env, where profile_rc
    # is a local variable; fall back to the newest rc in the layout dir.
    if [ -f "''${profile_rc:-}" ]; then
      __chips_rc=$profile_rc
    elif declare -F direnv_layout_dir >/dev/null 2>&1; then
      for __chips_f in "$(direnv_layout_dir)"/*.rc; do
        if [ -f "$__chips_f" ]; then
          if [ -z "$__chips_rc" ] || [ "$__chips_f" -nt "$__chips_rc" ]; then
            __chips_rc=$__chips_f
          fi
        fi
      done
      unset __chips_f
    fi

    __chips_read_stamp() {
      __chips_stamp_gen=0
      __chips_stamp_hash=""
      if [ -f "$1" ]; then
        read -r __chips_stamp_gen __chips_stamp_hash _ < "$1" || true
      fi
      case "$__chips_stamp_gen" in
        "" | *[!0-9]*) __chips_stamp_gen=0 ;;
      esac
    }

    __chips_when() {
      ${coreutils}/date -d "@$(($1 / 1000000000))" '+%F %T'
    }

    __chips_setup_needed() {
      __chips_gen=""
      if [ -n "$__chips_rc" ]; then
        read -r __chips_birth __chips_gen __chips_mtime \
          < <(${coreutils}/stat -c '%W %.9W %.9Y' "$__chips_rc") || true
        # Filesystems without birth times report 0 (or "-"); mtime still
        # orders generations, it just re-runs hooks on cached entries.
        case "''${__chips_birth:-}" in
          "" | 0 | -) __chips_gen=''${__chips_mtime:-} ;;
        esac
        __chips_gen=''${__chips_gen/./}
      fi
      case "$__chips_gen" in
        "" | *[!0-9]*) __chips_gen=$(${coreutils}/date +%s%N) ;;
      esac

      __chips_dir_stamp="$__chips_data_dir/.dev-shell.gen.d/$(printf %s "$PWD" | ${coreutils}/sha256sum | ${coreutils}/cut -c1-16)"
      __chips_read_stamp "$__chips_dir_stamp"
      if [ "$__chips_stamp_gen" = "$__chips_gen" ] && [ "$__chips_stamp_hash" = "$__chips_hash" ]; then
        # This generation already ran from this directory.
        return 1
      fi

      __chips_read_stamp "$__chips_data_dir/.dev-shell.gen"
      if [ "$__chips_stamp_gen" -gt "$(${coreutils}/date +%s%N)" ]; then
        # A marker from the future can only come from a clock jump; ignore it.
        __chips_stamp_gen=0
      fi
      __chips_shared_gen=$__chips_stamp_gen
      # Identical hooks are harmless to re-run (they only refresh this
      # directory's outputs), so only refuse when the hooks actually differ.
      if [ "$__chips_shared_gen" -gt "$__chips_gen" ] && [ "$__chips_stamp_hash" != "$__chips_hash" ]; then
        echo "nix-chips: setup hooks skipped: this cached devShell ($(__chips_when "$__chips_gen")) is older than the one applied at $(__chips_when "$__chips_shared_gen"); run 'direnv reload' here" >&2
        return 1
      fi
      return 0
    }

    __chips_stamp_generation() {
      ${coreutils}/mkdir -p "$__chips_data_dir/.dev-shell.gen.d"
      ${optionalString isPwdData ''printf '*\n' > "$__chips_data_dir/.gitignore"''}
      printf '%s %s\n' "$__chips_gen" "$__chips_hash" > "$__chips_dir_stamp"
      if [ "$__chips_gen" -ge "$__chips_shared_gen" ]; then
        printf '%s %s\n' "$__chips_gen" "$__chips_hash" > "$__chips_data_dir/.dev-shell.gen"
      fi
    }

    if __chips_setup_needed; then
      ${cfg.shellHooks}
      __chips_stamp_generation
    fi
    ${pkgs.flock}/bin/flock -u "$__chips_lock_fd"
    exec {__chips_lock_fd}>&-
    unset __chips_lock_fd
    unset -f __chips_read_stamp __chips_when __chips_setup_needed __chips_stamp_generation
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

    ${setupGate}

    # Activation hooks populate the current process environment on every
    # activation. They run after the setup hooks so files those just produced
    # (decrypted env files, ...) are available on the first activation too.
    ${cfg.activationHooks}
  '';
in {
  imports = [
    (mkRemovedOptionModule ["devShell" "generationId"] ''
      Setup hooks are now gated on the nix-direnv cache generation instead of
      a flake timestamp; see the devShell.shellHooks description and README.
    '')
  ];

  options = with lib.types; {
    devShell = {
      enable = mkEnableOption "Enable Developer Shell";

      requireProjectDirectory = mkEnableOption "Require the project directory to be set";

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
        description = ''
          Setup hooks that write project state: symlinked generated configs
          (Taskfile.yml, lefthook.yml, ...), decrypted secrets, mutable files.

          Under nix-direnv these run once per cache generation per entry
          directory. Concurrent setup runs sharing dir.data are serialized.
          A generation is one fresh evaluation of the flake, which
          happens on `direnv reload` or when flake.nix / flake.lock is newer
          than the cache; merely entering the directory or opening a new
          terminal never re-runs them. `direnv reload` therefore re-applies the
          configuration and recreates deleted generated files. A cached shell
          that is older than a generation already applied from another
          directory (for example a sibling checkout sharing this flake) skips
          the hooks with a warning until it is reloaded. Under `nix develop`
          the hooks run on every entry.

          Markers live at <dir.data>/.dev-shell.gen (newest generation applied)
          and <dir.data>/.dev-shell.gen.d/ (per entry directory), or under
          $PWD/.chips when dir.project is unset. Delete .dev-shell.gen to reset.
        '';
      };

      activationHooks = mkOption {
        type = lines;
        default = "";
        description = ''
          Hooks that run on every devShell activation, after the setup hooks
          whether or not those ran. Use this for anything that only exports
          environment (for example loading decrypted env files); it must not
          write project files.
        '';
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
