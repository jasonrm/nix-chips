{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.go;
in {
  options = with lib.types; {
    programs.go = {
      enable = mkEnableOption "go support";

      pkg = mkOption {
        type = package;
        default = pkgs.go;
      };
    };
  };

  config = {
    chips.devShell = mkIf cfg.enable {
      contents = [
        cfg.pkg
      ];
    };

    outputs.apps.go = {
      program = "${cfg.pkg}/bin/go";
    };
  };
}
