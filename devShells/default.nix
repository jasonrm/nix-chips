{
  lib,
  pkgs,
  ...
}: {
  config = {
    programs.bun = {
      enable = true;
      workingDirectory = "docs";
      linter = "none";
    };

    programs.taskfile.config.tasks = let
      copyDocsData = ''
        DATA_OUT="$(${pkgs.nix}/bin/nix build .#docs-data --no-link --print-out-paths)"
        ${pkgs.findutils}/bin/find docs/public/data -mindepth 1 ! -name .gitkeep -exec ${pkgs.coreutils}/bin/rm -rf {} +
        ${pkgs.coreutils}/bin/cp -R "$DATA_OUT"/. docs/public/data/
      '';
    in {
      docs-data = {
        desc = "Generate docs data";
        cmds = [copyDocsData];
        sources = [
          "docs/generate-options.nix"
          "docs/split-options.ts"
          "lib/**/*.nix"
          "modules/**/*.nix"
        ];
        generates = [
          "docs/public/data/_index.json"
          "docs/public/data/lib/mkFlake.json"
        ];
      };

      docs-dev = {
        desc = "Run docs development server";
        deps = [
          "docs-data"
          "install-bun"
        ];
        dir = "docs";
        cmds = ["${pkgs.bun}/bin/bun run dev"];
      };

      docs-build = {
        desc = "Build docs for production";
        deps = [
          "docs-data"
          "install-bun"
        ];
        dir = "docs";
        cmds = ["${pkgs.bun}/bin/bun run build"];
      };

      dev = lib.mkForce {
        desc = "Run docs development server";
        cmds = [{task = "docs-dev";}];
      };

      build = lib.mkForce {
        desc = "Build docs for production";
        deps = ["docs-build"];
      };
    };

    programs.jujutsu.enable = true;
  };
}
