{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.rust;
in {
  options = with lib.types; {
    programs.rust = {
      enable = mkEnableOption "rust support";
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      contents = [
        pkgs.cargo
        pkgs.cargo-sort
        pkgs.fuzz
        pkgs.rustfmt
      ];
    };
  };
}
