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
    programs.lefthook.config = {
      pre-commit = {
        commands = {
          eslint = {
            glob = mkDefault "*.{js,ts,jsx,tsx}";
            run = mkDefault "./node_modules/.bin/eslint --fix --max-warnings 0 {staged_files} && git add {staged_files}";
          };
          # tsc = {
          #   glob = "*.{ts,tsx}";
          #   run = "tsx ./tools/tsconfig-lint-staged.ts {staged_files} && tsc --noEmit --project tsconfig-lint-staged.json";
          # };
        };
      };
      pre-push = {
        commands = {
          eslint = {
            glob = mkDefault "*.{js,ts,jsx,tsx}";
            run = mkDefault "${pkgs.nodejs}/bin/node ./node_modules/.bin/eslint --cache --max-warnings 0 .";
          };
          tsc = {
            glob = mkDefault "*.{ts,tsx}";
            run = mkDefault "${pkgs.typescript}/bin/tsc --noEmit --project tsconfig.json";
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
