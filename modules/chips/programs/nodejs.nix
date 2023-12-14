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

      nodePackages = mkOption {
        type = package;
        default = pkgs.nodePackages;
      };
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      shellHooks = ''
        echo node: ${cfg.pkg}/bin/node
        [[ ":$PATH:" != *":/node_modules/.bin:"* ]] && export PATH="$PATH:$(pwd)/node_modules/.bin"
      '';
      contents = with cfg.nodePackages; [
        nodejs
        pnpm
      ];
    };

    #    outputs.apps.node = {
    #      program = "${cfg.pkg}/bin/node";
    #    };
    #
    #    outputs.apps.npm = {
    #      program = "${cfg.pkg}/bin/npm";
    #    };
  };
}
