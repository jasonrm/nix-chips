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
        default = pkgs.nodejs;
      };
    };
  };

  config = {
    shell = mkIf cfg.enable {
      shellHooks = [
        ''echo node: ${cfg.pkg}/bin/node''
      ];
      contents = [
        cfg.pkg
      ];
    };

    outputs.apps.node = {
      program = "${cfg.pkg}/bin/node";
    };

    outputs.apps.npm = {
      program = "${cfg.pkg}/bin/npm";
    };
  };
}
