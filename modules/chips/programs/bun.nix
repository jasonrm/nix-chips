{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.bun;
in {
  options = with lib.types; {
    programs.bun = {
      enable = mkEnableOption "bun support";

      pkg = mkOption {
        type = package;
        default = pkgs.bun;
      };

      workingDirectory = mkOption {
        type = nullOr str;
        default =
          if config.dir.project != "/dev/null"
          then config.dir.project
          else null;
      };
    };
  };

  config = mkIf cfg.enable {
    programs.taskfile.enable = mkDefault true;
    programs.taskfile.config.tasks = {
      install-bun = {
        dir = cfg.workingDirectory;
        cmds = ["${cfg.pkg}/bin/bun install"];
        generates = ["node_modules/.bin"];
        desc = "Install Dependencies (bun)";
        sources = [
          "package.json"
          "bun.lock"
        ];
      };
      update-bun = {
        dir = cfg.workingDirectory;
        cmds = ["${cfg.pkg}/bin/bun update"];
        desc = "Update Dependencies (bun)";
      };
      build-bun = {
        dir = cfg.workingDirectory;
        cmds = ["${cfg.pkg}/bin/bun run build"];
        desc = "Build Project (bun)";
        deps = ["install-bun"];
      };
      check-bun = {
        dir = cfg.workingDirectory;
        cmds = ["${cfg.pkg}/bin/bun install --frozen-lockfile"];
        desc = "Check Project Dependencies";
        sources = [
          "package.json"
          "bun.lock"
        ];
      };

      format-eslint = {
        dir = cfg.workingDirectory;
        cmds = [''${cfg.pkg}/bin/bun run eslint --cache --fix --max-warnings 0 {{.CLI_ARGS}}''];
        preconditions = ["test -f ./node_modules/.bin/eslint"];
        deps = ["install-bun"];
        desc = "Format JavaScript and TypeScript files";
      };
      check-eslint = {
        dir = cfg.workingDirectory;
        cmds = [''${cfg.pkg}/bin/bun run eslint --cache --max-warnings 0''];
        preconditions = ["test -f ./node_modules/.bin/eslint"];
        deps = ["install-bun"];
        desc = "Check JavaScript and TypeScript files";
      };

      check-tsc = {
        dir = cfg.workingDirectory;
        cmds = ["${cfg.pkg}/bin/bun run tsc --noEmit --project tsconfig.json"];
        preconditions = ["test -f tsconfig.json"];
        deps = ["install-bun"];
        desc = "Check TypeScript files";
      };

      format.deps = ["format-eslint"];
      check.deps = [
        "check-eslint"
        "check-tsc"
        "check-bun"
      ];
      install.deps = ["install-bun"];
      update.deps = ["update-bun"];
      build.deps = ["build-bun"];
    };

    programs.lefthook.config = {
      pre-commit = {
        commands = {
          format-eslint = {
            glob = mkDefault "*.{js,ts,jsx,tsx}";
            run = mkDefault "${pkgs.go-task}/bin/task format-eslint -- {staged_files}";
            stage_fixed = true;
            root = mkDefault cfg.workingDirectory;
          };
        };
      };
      pre-push = {
        commands = {
          check-eslint = {
            glob = mkDefault "*.{js,ts,jsx,tsx}";
            run = mkDefault "${pkgs.go-task}/bin/task check-eslint";
            root = mkDefault cfg.workingDirectory;
          };
          check-tsc = {
            glob = mkDefault "*.{ts,tsx}";
            run = mkDefault "${pkgs.go-task}/bin/task check-tsc";
            root = mkDefault cfg.workingDirectory;
          };
          check-bun = {
            glob = mkDefault "{package.json,bun.lock}";
            run = mkDefault "${pkgs.go-task}/bin/task check-bun";
            root = mkDefault cfg.workingDirectory;
          };
        };
      };
    };

    devShell = {
      environment = let
        workingDirectory =
          if cfg.workingDirectory != null
          then cfg.workingDirectory
          else "$PWD";
      in ["PATH=$PATH:${workingDirectory}/node_modules/.bin"];
      contents = [cfg.pkg];
    };
  };
}
