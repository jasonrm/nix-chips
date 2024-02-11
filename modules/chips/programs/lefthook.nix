{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.lefthook;

  leftHookConfigFile = pkgs.writeText "lefthook.yml" (builtins.toJSON cfg.config);

  lefthookCommand = with types; {
    options = {
      glob = mkOption {
        type = nullOr str;
        default = null;
      };
      run = mkOption {
        type = str;
      };
      skip = mkOption {
        type = bool;
        default = false;
      };
      stage_fixed = mkOption {
        type = bool;
        default = false;
      };
    };
  };

  lefthookConfig = with types; {
    options = {
      commands = mkOption {
        type = nullOr (attrsOf (submodule lefthookCommand));
      };
      parallel = mkOption {
        type = nullOr bool;
      };
    };
  };

  lefthookGlobalConfig = with types; {
    options = {
      skip_output = mkOption {
        type = listOf str;
        default = [];
      };
      pre-commit = mkOption {
        type = submodule lefthookConfig;
        default = {};
      };
      pre-push = mkOption {
        type = submodule lefthookConfig;
        default = {};
      };
    };
  };
in {
  options = {
    programs.lefthook = with types; {
      enable = mkEnableOption "lefthook support";
      config = mkOption {
        type = submodule lefthookGlobalConfig;
        default = {};
      };
    };
  };

  config = mkIf cfg.enable {
    programs.taskfile.config.tasks = {
      check-unresovled-conflicts = {
        desc = "Check For Unresolved Git Conflicts";
        cmds = [''! ${pkgs.ripgrep}/bin/rg "(^[<>=]{5,})$" --with-filename --count {{.CLI_ARGS | default "."}}''];
      };

      check = {
        deps = ["check-unresovled-conflicts"];
      };
    };

    programs.lefthook.config = {
      skip_output = [
        "meta"
        "execution"
        "execution_out"
      ];
      pre-commit = {
        commands = {
          format-nix = {
            glob = mkDefault "*.nix";
            run = mkDefault "${pkgs.go-task}/bin/task format-nix -- {staged_files}";
            stage_fixed = true;
          };
          jpegtran = {
            glob = mkDefault "*.{jpg,jpeg}";
            run = mkDefault "for FILE in {staged_files}; do jpegtran -copy none -optimize -progressive -outfile $FILE $FILE; done";
            stage_fixed = true;
          };
          oxipng = {
            glob = mkDefault "*.png";
            run = mkDefault "${pkgs.oxipng}/bin/oxipng -o 3 -i 0 --strip safe {staged_files}";
            stage_fixed = true;
          };
          format-json = {
            glob = mkDefault "*.json";
            run = mkDefault "${pkgs.go-task}/bin/task format-json -- {staged_files}";
            stage_fixed = true;
          };
          check-unresovled-conflicts = {
            run = mkDefault "${pkgs.go-task}/bin/task check-unresovled-conflicts -- {staged_files}";
          };
        };
        parallel = true;
      };
      pre-push = {
        commands = {};
        parallel = true;
      };
    };
    devShell = {
      contents = [
        pkgs.lefthook
      ];
      shellHooks = ''
        ln -sf ${leftHookConfigFile} lefthook.yml
        ${pkgs.lefthook}/bin/lefthook install
      '';
    };
  };
}
