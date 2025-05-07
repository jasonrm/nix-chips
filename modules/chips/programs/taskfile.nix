{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.programs.taskfile;

  taskfileConfigFile = pkgs.writeText "Taskfile.yml" (builtins.toJSON cfg.config);

  taskSourceSubmodule = with types; {
    options = {
      exclude = mkOption { type = str; };
    };
  };

  taskCommandSubmodule = with types; {
    options = {
      cmd = mkOption { type = str; };
      for = mkOption {
        type = nullOr (oneOf [
          attrs
          str
        ]);
        default = null;
      };
    };
  };

  taskPreconditionSubmodule = with types; {
    options = {
      sh = mkOption { type = str; };
      msg = mkOption { type = str; };
    };
  };

  taskSubmodule = with types; {
    options = {
      cmds = mkOption {
        type = listOf (oneOf [
          str
          (submodule taskCommandSubmodule)
        ]);
        default = [ ];
      };
      preconditions = mkOption {
        type = listOf (oneOf [
          str
          (submodule taskPreconditionSubmodule)
        ]);
        default = [ ];
      };
      deps = mkOption {
        type = nullOr (listOf str);
        default = null;
      };
      generates = mkOption {
        type = nullOr (listOf str);
        default = null;
      };
      env = mkOption {
        type = attrsOf str;
        default = { };
      };
      sources = mkOption {
        type = listOf (oneOf [
          str
          (submodule taskSourceSubmodule)
        ]);
        default = [ ];
      };
      desc = mkOption { type = str; };
      dir = mkOption {
        type = nullOr str;
        default = null;
      };
    };
  };

  taskfileConfig = with types; {
    options = {
      tasks = mkOption {
        type = attrsOf (submodule taskSubmodule);
        default = { };
      };
      version = mkOption {
        type = str;
        default = "3";
      };
    };
  };
in
{
  options = {
    programs.taskfile = with types; {
      enable = mkEnableOption "taskfile support";
      config = mkOption {
        type = submodule taskfileConfig;
        default = { };
      };
    };
  };

  config = mkIf cfg.enable {
    programs.taskfile.config.tasks = {
      update-nix = {
        desc = "Update Nix Flakes";
        cmds = [ "${pkgs.nix}/bin/nix flake update" ];
      };

      format-nix = {
        desc = "Format Nix Files";
        cmds = [ ''${pkgs.alejandra}/bin/alejandra {{.CLI_ARGS | default "." }}'' ];
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
        deps = [ "format-nix" ];
      };
      install = {
        desc = "Run All Install Tasks";
      };
      update = {
        desc = "Run All Update Tasks";
        deps = [ "update-nix" ];
      };
      build = {
        desc = "Run All Build Tasks";
      };
    };
    devShell = {
      contents = [ pkgs.go-task ];
      shellHooks = ''
        ln -sf ${taskfileConfigFile} Taskfile.yml
      '';
    };
  };
}
