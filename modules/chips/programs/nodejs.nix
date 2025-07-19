{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  inherit (pkgs.writers) writeBashBin;

  cfg = config.programs.nodejs;
in
{
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

      packageManager = mkOption {
        type = enum [
          "npm"
          "pnpm"
        ];
        default = "pnpm";
      };

      workingDirectory = mkOption {
        type = nullOr str;
        default = if config.dir.project != "/dev/null" then config.dir.project else null;
      };
    };
  };

  config = mkIf cfg.enable {
    programs.taskfile.enable = mkDefault true;
    programs.taskfile.config.tasks = {
      install-npm =
        if cfg.packageManager == "pnpm" then
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.pnpm}/bin/pnpm install" ];
            generates = [ "node_modules/.modules.yaml" ];
            desc = "Install Node.JS Dependencies (pnpm)";
            sources = [
              "package.json"
              "pnpm-lock.yaml"
            ];
          }
        else
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.npm}/bin/npm install" ];
            generates = [ "node_modules/.package-lock.json" ];
            desc = "Install Node.JS Dependencies (npm)";
            sources = [
              "package.json"
              "package-lock.json"
            ];
          };
      update-npm =
        if cfg.packageManager == "pnpm" then
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.pnpm}/bin/pnpm update" ];
            desc = "Update Node.JS Dependencies (pnpm)";
          }
        else
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.npm}/bin/npm update" ];
            desc = "Update Node.JS Dependencies (npm)";
          };
      build-npm =
        if cfg.packageManager == "pnpm" then
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.pnpm}/bin/pnpm run build" ];
            desc = "Build Node.JS Project (pnpm)";
            deps = [ "install-npm" ];
          }
        else
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.npm}/bin/npm run build" ];
            desc = "Build Node.JS Project (npm)";
            deps = [ "install-npm" ];
          };
      check-npm =
        if cfg.packageManager == "pnpm" then
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.pnpm}/bin/pnpm install --frozen-lockfile" ];
            desc = "Check Node.JS Project";
            sources = [
              "package.json"
              "pnpm-lock.yaml"
            ];
          }
        else
          {
            dir = cfg.workingDirectory;
            cmds = [ "${pkgs.nodePackages.npm}/bin/npm ci" ];
            desc = "Check Node.JS Project";
            sources = [
              "package.json"
              "package-lock.json"
            ];
          };

      format-eslint = {
        dir = cfg.workingDirectory;
        cmds = [
          ''${pkgs.nodejs}/bin/node ./node_modules/eslint/bin/eslint.js --cache --fix --max-warnings 0 {{.CLI_ARGS}}''
        ];
        preconditions = [ "test -f ./node_modules/eslint/bin/eslint.js" ];
        deps = [ "install-npm" ];
        desc = "Format JavaScript and TypeScript files";
      };
      check-eslint = {
        dir = cfg.workingDirectory;
        cmds = [ ''${pkgs.nodejs}/bin/node ./node_modules/eslint/bin/eslint.js --cache --max-warnings 0'' ];
        preconditions = [ "test -f ./node_modules/eslint/bin/eslint.js" ];
        deps = [ "install-npm" ];
        desc = "Check JavaScript and TypeScript files";
      };

      check-tsc = {
        dir = cfg.workingDirectory;
        cmds = [ "${pkgs.typescript}/bin/tsc --noEmit --project tsconfig.json" ];
        preconditions = [ "test -f tsconfig.json" ];
        desc = "Check TypeScript files";
      };

      format.deps = [ "format-eslint" ];
      check.deps = [
        "check-eslint"
        "check-tsc"
        "check-npm"
      ];
      install.deps = [ "install-npm" ];
      update.deps = [ "update-npm" ];
      build.deps = [ "build-npm" ];
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
          check-npm = {
            glob = mkDefault "{package.json,pnpm-lock.yaml}";
            run = mkDefault "${pkgs.go-task}/bin/task check-npm";
            root = mkDefault cfg.workingDirectory;
          };
        };
      };
    };

    devShell = {
      environment =
        let
          workingDirectory = if cfg.workingDirectory != null then cfg.workingDirectory else "$PWD";
        in
        [ "PATH=$PATH:${workingDirectory}/node_modules/.bin" ];
      contents = with cfg.nodePackages; [
        nodejs
        pnpm
      ];
    };
  };
}
