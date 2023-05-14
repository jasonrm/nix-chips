{
  lib,
  pkgs,
  config,
  chips,
  ...
}: let
  cfg = config.dir;
in
  with lib; {
    imports = [
    ];

    options = with types; {
      dir = {
        project = mkOption {
          type = str;
          default = "/dev/null";
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

    config = mkIf (cfg.project != "/dev/null") {
      dir.ensureExists = [
        cfg.data
      ];
      chips.devShell.shellHooks = ''
        mkdir -p ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.ensureExists)}
        echo '*' > ${cfg.data}/.gitignore
      '';
    };
  }
