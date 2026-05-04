{
  lib,
  pkgs,
  config,
  chips,
  ...
}:
with lib; let
  cfg = config.devShell.llm;
  inherit (config.dir) project;
in {
  options = with types; {
    devShell.llm = {
      enable = mkOption {
        type = bool;
        default = true;
        description = ''
          When enabled, creates a .llm directory in the project root with
          symlinks to the nix-chips source, providing LLM tools with access
          to the framework source code for context-aware assistance.
        '';
      };
    };
  };

  config = mkIf (cfg.enable && project != "/dev/null") {
    devShell.shellHooks = mkAfter ''
      LLM_DIR="${project}/.llm"
      mkdir -p "$LLM_DIR"
      echo '*' > "$LLM_DIR/.gitignore"
      ln -sfn "${chips}" "$LLM_DIR/nix-chips"
    '';
  };
}
