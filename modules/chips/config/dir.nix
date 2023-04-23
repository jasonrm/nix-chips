{
  lib,
  pkgs,
  config,
  chips,
  ...
}: let
  inherit (lib) mkOption assertMsg;
  cfg = config.dir;
in {
  imports = [
  ];

  options = with lib.types; {
    dir = {
      project = mkOption {
        type = str;
        default = chips.requireImpureEnv "PWD";
      };

      data = mkOption {
        type = str;
        default = cfg.project + "/data";
      };

      ensureExists = mkOption {
        type = listOf str;
        default = [];
      };
    };
  };

  config = {
    dir.ensureExists = [
      cfg.data
    ];
    chips.devShell.shellHooks = [
      ''
        mkdir -p ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.ensureExists)}
        echo '*' > ${cfg.data}/.gitignore
      ''
    ];
  };
}
