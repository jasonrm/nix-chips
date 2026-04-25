{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.bun;

  eslintTasks = {
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
  };

  oxlintTasks = {
    format-oxlint = {
      dir = cfg.workingDirectory;
      cmds = [''${pkgs.oxlint}/bin/oxlint --fix {{.CLI_ARGS}}''];
      desc = "Format JavaScript and TypeScript files";
    };
    check-oxlint = {
      dir = cfg.workingDirectory;
      cmds = [''${pkgs.oxlint}/bin/oxlint --deny-warnings''];
      desc = "Check JavaScript and TypeScript files";
    };
  };

  linterTasks =
    {
      eslint = eslintTasks;
      oxlint = oxlintTasks;
      none = {};
    }.${
      cfg.linter
    };

  linterFormatDeps =
    {
      eslint = ["format-eslint"];
      oxlint = ["format-oxlint"];
      none = [];
    }.${
      cfg.linter
    };

  linterCheckDeps =
    {
      eslint = ["check-eslint"];
      oxlint = ["check-oxlint"];
      none = [];
    }.${
      cfg.linter
    };

  eslintLefthook = {
    pre-commit.commands.format-eslint = {
      glob = mkDefault "*.{js,ts,jsx,tsx}";
      run = mkDefault "${pkgs.go-task}/bin/task format-eslint -- {staged_files}";
      stage_fixed = true;
      root = mkDefault cfg.workingDirectory;
    };
    pre-push.commands.check-eslint = {
      glob = mkDefault "*.{js,ts,jsx,tsx}";
      run = mkDefault "${pkgs.go-task}/bin/task check-eslint";
      root = mkDefault cfg.workingDirectory;
    };
  };

  oxlintLefthook = {
    pre-commit.commands.format-oxlint = {
      glob = mkDefault "*.{js,ts,jsx,tsx}";
      run = mkDefault "${pkgs.go-task}/bin/task format-oxlint -- {staged_files}";
      stage_fixed = true;
      root = mkDefault cfg.workingDirectory;
    };
    pre-push.commands.check-oxlint = {
      glob = mkDefault "*.{js,ts,jsx,tsx}";
      run = mkDefault "${pkgs.go-task}/bin/task check-oxlint";
      root = mkDefault cfg.workingDirectory;
    };
  };

  linterLefthook =
    {
      eslint = eslintLefthook;
      oxlint = oxlintLefthook;
      none = {};
    }.${
      cfg.linter
    };
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

      linter = mkOption {
        type = enum ["eslint" "oxlint" "none"];
        default = "eslint";
        description = "Which linter to wire into format/check tasks and lefthook hooks.";
      };
    };
  };

  config = mkIf cfg.enable {
    programs.taskfile.enable = mkDefault true;
    programs.taskfile.config.tasks =
      {
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

        check-tsc = {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.pkg}/bin/bun run tsc --noEmit --project tsconfig.json"];
          preconditions = ["test -f tsconfig.json"];
          deps = ["install-bun"];
          desc = "Check TypeScript files";
        };

        format.deps = linterFormatDeps;
        check.deps =
          linterCheckDeps
          ++ [
            "check-tsc"
            "check-bun"
          ];
        install.deps = ["install-bun"];
        update.deps = ["update-bun"];
        build.deps = ["build-bun"];
      }
      // linterTasks;

    programs.lefthook.config = mkMerge [
      {
        pre-push.commands = {
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
      }
      linterLefthook
    ];

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
