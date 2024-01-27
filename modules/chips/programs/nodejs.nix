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

  config = {
    devShell = mkIf cfg.enable {
      environment = [
        "PATH=$PATH:${config.dir.project}/node_modules/.bin"
      ];
      contents = with cfg.nodePackages; [
        nodejs
        pnpm
      ];
    };
  };
}
