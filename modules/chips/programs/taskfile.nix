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

  taskfileConfigFile = pkgs.writeText "Taskfile.yml" (builtins.toJSON cfg.config);
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
    };
    devShell = {
      contents = [pkgs.go-task];
      shellHooks = ''
        ln -sf ${taskfileConfigFile} Taskfile.yml
      '';
    };
  };
}
