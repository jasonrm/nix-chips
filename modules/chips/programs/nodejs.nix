{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.nodejs;
  oxfmtPkg =
    if pkgs ? oxfmt
    then pkgs.oxfmt
    else if pkgs ? unstable && pkgs.unstable ? oxfmt
    then pkgs.unstable.oxfmt
    else throw "programs.nodejs.formatter=oxfmt requires pkgs.oxfmt or pkgs.unstable.oxfmt";
  oxlintPkg =
    if pkgs ? oxlint
    then pkgs.oxlint
    else if pkgs ? unstable && pkgs.unstable ? oxlint
    then pkgs.unstable.oxlint
    else throw "programs.nodejs.linter=oxlint requires pkgs.oxlint or pkgs.unstable.oxlint";

  eslintTasks = {
    format-eslint = {
      dir = cfg.workingDirectory;
      cmds = [
        ''${cfg.pkg}/bin/node ./node_modules/eslint/bin/eslint.js --cache --fix --max-warnings 0 {{.CLI_ARGS}}''
      ];
      preconditions = ["test -f ./node_modules/eslint/bin/eslint.js"];
      deps = ["install-npm"];
      desc = "Format JavaScript and TypeScript files";
    };
    check-eslint = {
      dir = cfg.workingDirectory;
      cmds = [''${cfg.pkg}/bin/node ./node_modules/eslint/bin/eslint.js --cache --max-warnings 0''];
      preconditions = ["test -f ./node_modules/eslint/bin/eslint.js"];
      deps = ["install-npm"];
      desc = "Check JavaScript and TypeScript files";
    };
  };

  oxcTasks = {
    format-oxfmt = {
      dir = cfg.workingDirectory;
      cmds = [''${oxfmtPkg}/bin/oxfmt --no-error-on-unmatched-pattern {{.CLI_ARGS}}''];
      desc = "Format JavaScript and TypeScript files";
    };
    check-oxfmt = {
      dir = cfg.workingDirectory;
      cmds = [''${oxfmtPkg}/bin/oxfmt --check .''];
      desc = "Check JavaScript and TypeScript formatting";
    };
    format-oxlint = {
      dir = cfg.workingDirectory;
      cmds = [''${oxlintPkg}/bin/oxlint --fix {{.CLI_ARGS}}''];
      desc = "Apply safe Oxlint fixes";
    };
    check-oxlint = {
      dir = cfg.workingDirectory;
      cmds = [''${oxlintPkg}/bin/oxlint --deny-warnings''];
      desc = "Check JavaScript and TypeScript files";
    };
  };

  formatTaskDeps =
    {
      eslint = ["format-eslint"];
      oxfmt = ["format-oxfmt"];
      none = [];
    }.${
      cfg.formatter
    };

  checkTaskDeps =
    {
      eslint = ["check-eslint"];
      oxlint = ["check-oxlint"];
      none = [];
    }.${
      cfg.linter
    }
    ++ optional (cfg.formatter == "oxfmt") "check-oxfmt";

  formatterLefthook =
    {
      eslint = {
        pre-commit.commands.format-eslint = {
          glob = mkDefault "*.{js,ts,jsx,tsx}";
          run = mkDefault "${pkgs.go-task}/bin/task format-eslint -- {staged_files}";
          stage_fixed = true;
          root = mkDefault cfg.workingDirectory;
        };
      };
      oxfmt = {
        pre-commit.commands.format-oxfmt = {
          glob = mkDefault "*.{js,ts,jsx,tsx}";
          run = mkDefault "${pkgs.go-task}/bin/task format-oxfmt -- {staged_files}";
          stage_fixed = true;
          root = mkDefault cfg.workingDirectory;
        };
      };
      none = {};
    }.${
      cfg.formatter
    };

  linterLefthook =
    {
      eslint = {
        pre-push.commands.check-eslint = {
          glob = mkDefault "*.{js,ts,jsx,tsx}";
          run = mkDefault "${pkgs.go-task}/bin/task check-eslint";
          root = mkDefault cfg.workingDirectory;
        };
      };
      oxlint = {
        pre-push.commands.check-oxlint = {
          glob = mkDefault "*.{js,ts,jsx,tsx}";
          run = mkDefault "${pkgs.go-task}/bin/task check-oxlint";
          root = mkDefault cfg.workingDirectory;
        };
      };
      none = {};
    }.${
      cfg.linter
    };

  formatterCheckLefthook = mkIf (cfg.formatter == "oxfmt") {
    pre-push.commands.check-oxfmt = {
      glob = mkDefault "*.{js,ts,jsx,tsx}";
      run = mkDefault "${pkgs.go-task}/bin/task check-oxfmt";
      root = mkDefault cfg.workingDirectory;
    };
  };
in {
  options = with lib.types; {
    programs.nodejs = {
      enable = mkEnableOption "nodejs support";

      pkg = mkOption {
        type = package;
        default = pkgs.nodejs_24;
      };

      nodePackages = mkOption {
        type = attrs;
        readOnly = true;
        default = cfg.pkg.pkgs;
      };

      packageManager = mkOption {
        type = enum [
          "npm"
          "pnpm"
        ];
        default = "pnpm";
      };

      formatter = mkOption {
        type = enum [
          "eslint"
          "oxfmt"
          "none"
        ];
        default = "oxfmt";
        description = "Which formatter to wire into format tasks and pre-commit hooks.";
      };

      linter = mkOption {
        type = enum [
          "eslint"
          "oxlint"
          "none"
        ];
        default = "oxlint";
        description = "Which linter to wire into check tasks and pre-push hooks.";
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
      install-npm =
        if cfg.packageManager == "pnpm"
        then {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.nodePackages.pnpm}/bin/pnpm install"];
          generates = ["node_modules/.modules.yaml"];
          desc = "Install Node.JS Dependencies (pnpm)";
          sources = [
            "package.json"
            "pnpm-lock.yaml"
          ];
        }
        else {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.pkg}/bin/npm install"];
          generates = ["node_modules/.package-lock.json"];
          desc = "Install Node.JS Dependencies (npm)";
          sources = [
            "package.json"
            "package-lock.json"
          ];
        };
      update-npm =
        if cfg.packageManager == "pnpm"
        then {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.nodePackages.pnpm}/bin/pnpm update"];
          desc = "Update Node.JS Dependencies (pnpm)";
        }
        else {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.pkg}/bin/npm update"];
          desc = "Update Node.JS Dependencies (npm)";
        };
      build-npm =
        if cfg.packageManager == "pnpm"
        then {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.nodePackages.pnpm}/bin/pnpm run build"];
          desc = "Build Node.JS Project (pnpm)";
          deps = ["install-npm"];
        }
        else {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.pkg}/bin/npm run build"];
          desc = "Build Node.JS Project (npm)";
          deps = ["install-npm"];
        };
      check-npm =
        if cfg.packageManager == "pnpm"
        then {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.nodePackages.pnpm}/bin/pnpm install --frozen-lockfile"];
          desc = "Check Node.JS Project";
          sources = [
            "package.json"
            "pnpm-lock.yaml"
          ];
        }
        else {
          dir = cfg.workingDirectory;
          cmds = ["${cfg.pkg}/bin/npm ci"];
          desc = "Check Node.JS Project";
          sources = [
            "package.json"
            "package-lock.json"
          ];
        };

      check-tsc = {
        dir = cfg.workingDirectory;
        cmds = ["${pkgs.typescript}/bin/tsc --noEmit --project tsconfig.json"];
        preconditions = ["test -f tsconfig.json"];
        desc = "Check TypeScript files";
      };

      format.deps = formatTaskDeps;
      check.deps =
        checkTaskDeps
        ++ [
          "check-tsc"
          "check-npm"
        ];
      install.deps = ["install-npm"];
      update.deps = ["update-npm"];
      build.deps = ["build-npm"];
    }
    // eslintTasks
    // oxcTasks;

    programs.lefthook.config = mkMerge [
      {
        pre-push.commands = {
          check-tsc = {
            glob = mkDefault "*.{ts,tsx}";
            run = mkDefault "${pkgs.go-task}/bin/task check-tsc";
            root = mkDefault cfg.workingDirectory;
          };
          check-npm = {
            glob = mkDefault "{package.json,pnpm-lock.yaml}";
            run = mkDefault "${pkgs.go-task}/bin/task check-npm";
            root = mkDefault cfg.workingDirectory;
          };
        };
      }
      formatterLefthook
      formatterCheckLefthook
      linterLefthook
    ];

    devShell = {
      environment = let
        workingDirectory =
          if cfg.workingDirectory != null
          then cfg.workingDirectory
          else "$PWD";
      in ["PATH=$PATH:${workingDirectory}/node_modules/.bin"];
      contents =
        [
          cfg.pkg
        ]
        ++ optional (cfg.packageManager == "pnpm") cfg.nodePackages.pnpm
        ++ optional (cfg.formatter == "oxfmt") oxfmtPkg
        ++ optional (cfg.linter == "oxlint") oxlintPkg;
    };
  };
}
