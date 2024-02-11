{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  inherit (pkgs.writers) writeBashBin;

  cfg = config.programs.nodejs;
in {
  options = with lib.types; {
    programs.nodejs = {
      enable = mkEnableOption "nodejs support";

      pkg = mkOption {
        type = package;
        default = config.programs.nodejs.nodePackages.nodejs;
      };

      nodePackages = mkOption {
        type = attrs;
        default = pkgs.nodePackages;
      };
    };
  };

  config = mkIf cfg.enable {
    programs.taskfile.config.tasks = {
      install-npm = {
        cmds = ["${pkgs.nodePackages.pnpm}/bin/pnpm install"];
        generates = ["node_modules/.modules.yaml"];
        desc = "Install Node.JS Dependencies";
        sources = ["package.json" "pnpm-lock.yaml"];
      };
      update-npm = {
        cmds = ["${pkgs.nodePackages.pnpm}/bin/pnpm update"];
        desc = "Update Node.JS Dependencies";
        sources = ["package.json"];
      };
      build-npm = {
        cmds = ["${pkgs.nodePackages.pnpm}/bin/pnpm run build"];
        desc = "Build Node.JS Project";
        deps = ["install-npm"];
      };

      format-eslint = {
        cmds = [''${pkgs.nodejs}/bin/node ./node_modules/eslint/bin/eslint.js --cache --fix --max-warnings 0 {{.CLI_ARGS}}''];
        preconditions = [
          "test -f ./node_modules/eslint/bin/eslint.js"
        ];
        desc = "Format JavaScript and TypeScript files";
      };
      check-eslint = {
        cmds = [''${pkgs.nodejs}/bin/node ./node_modules/eslint/bin/eslint.js --cache --max-warnings 0''];
        preconditions = [
          "test -f ./node_modules/eslint/bin/eslint.js"
        ];
        desc = "Check JavaScript and TypeScript files";
      };

      check-tsc = {
        cmds = ["${pkgs.typescript}/bin/tsc --noEmit --project tsconfig.json"];
        preconditions = [
          "test -f tsconfig.json"
        ];
        desc = "Check TypeScript files";
      };

      format.deps = ["format-eslint"];
      check.deps = ["check-eslint" "check-tsc"];
      install.deps = ["install-npm"];
      update.deps = ["update-npm"];
      build.deps = ["build-npm"];
    };

    programs.lefthook.config = {
      pre-commit = {
        commands = {
          format-eslint = {
            glob = mkDefault "*.{js,ts,jsx,tsx}";
            run = mkDefault "${pkgs.go-task}/bin/task format-eslint -- {staged_files}";
            stage_fixed = true;
          };
        };
      };
      pre-push = {
        commands = {
          check-eslint = {
            glob = mkDefault "*.{js,ts,jsx,tsx}";
            run = mkDefault "${pkgs.go-task}/bin/task check-eslint";
          };
          check-tsc = {
            glob = mkDefault "*.{ts,tsx}";
            run = mkDefault "${pkgs.go-task}/bin/task check-tsc";
          };
        };
      };
    };

    devShell = {
      environment = let
        projectDir =
          if config.dir.project != "/dev/null"
          then config.dir.project
          else "$PWD";
      in [
        "PATH=$PATH:$PWD/node_modules/.bin"
      ];
      contents = with cfg.nodePackages; [
        nodejs
        pnpm
      ];
    };
  };
}
