{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.taskfile;

  jsonFormat = pkgs.formats.json {};

  taskSubmodule = types.submodule {
    freeformType = jsonFormat.type;
    options.deps = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };

  titleCommand = {
    silent = true;
    cmd = ''
      if [ -t 2 ]; then
        printf '\033]0;task %s\007\033]7501;state=working:app=task\033\\' {{regexReplaceAll "[\\p{Cc}\\p{Cf}]" .TASK "" | shellQuote}} >&2
      fi
    '';
  };

  # Add this after module merging, so even mkForce command lists get the title.
  # Task still owns dependency ordering, caching, and command execution.
  taskfileConfig =
    cfg.config
    // {
      tasks = mapAttrs (_: task:
        assert !(task ? cmd && task ? cmds);
          removeAttrs task ["cmd"]
          // {
            cmds =
              [titleCommand]
              ++ (
                if task ? cmd
                then [task.cmd]
                else task.cmds or []
              );
          })
      cfg.config.tasks;
    };
  taskfileConfigFile = pkgs.writeText "Taskfile.yml" (builtins.toJSON taskfileConfig);
in {
  options = {
    programs.taskfile = with types; {
      enable = mkEnableOption "taskfile support";
      config = mkOption {
        type = submodule {
          freeformType = jsonFormat.type;
          options.tasks = mkOption {
            type = attrsOf taskSubmodule;
            default = {};
          };
        };
        default = {};
        description = "Freeform Taskfile configuration. Supports any valid Taskfile YAML structure as a Nix attrset.";
      };
    };
  };

  config = mkIf cfg.enable {
    programs.taskfile.config.version = "3";
    programs.taskfile.config.tasks = {
      update-nix = {
        desc = "Update Nix Flakes";
        cmds = ["${pkgs.nix}/bin/nix flake update"];
      };

      format-nix = {
        desc = "Format Nix Files";
        cmds = [''${pkgs.alejandra}/bin/alejandra {{.CLI_ARGS | default "." }}''];
      };
      format-json = {
        desc = "Format JSON Files";
        cmds = [
          ''for FILE in {{.CLI_ARGS | default "*.json" }}; do ${pkgs.jq}/bin/jq --sort-keys --indent 2 . "$FILE" > "$FILE".tmp && mv "$FILE".tmp "$FILE"; done''
        ];
      };

      check = {
        desc = "Run All Check Tasks";
      };
      format = {
        desc = "Run All Format Tasks";
        deps = ["format-nix"];
      };
      install = {
        desc = "Run All Install Tasks";
      };
      update = {
        desc = "Run All Update Tasks";
        deps = ["update-nix"];
      };
      build = {
        desc = "Run All Build Tasks";
      };
      dev = {
        # Generic fallback for projects without a dev server. Use mkOptionDefault
        # (weaker than mkDefault) so modules like supervisord can claim `dev` with
        # their own mkDefault, and projects can still override either.
        desc = mkOptionDefault "Start the development environment (override or extend per project)";
      };
    };
    devShell = {
      contents = [pkgs.go-task];
      shellHooks = ''
        ln -sf ${taskfileConfigFile} Taskfile.yml
      '';
    };
  };
}
