{
  lib,
  pkgs,
  config,
  chips,
  ...
}:
let
  cfg = config.dir;
in
with lib;
{
  imports = [ ];

  options = with types; {
    dir = {
      project = mkOption {
        type = str;
        default = "/dev/null";
      };

      data = mkOption {
        type = str;
        default = cfg.project + "/.chips";
      };

      ensureExists = mkOption {
        type = listOf str;
        default = [ ];
      };
    };
  };

  config = mkIf (cfg.project != "/dev/null") {
    devShell.environment = [
      "NIX_CHIPS_DIR_PROJECT=${cfg.project}"
      "NIX_CHIPS_DIR_DATA=${cfg.data}"
    ];
    dir.ensureExists = [ cfg.data ];
    devShell.shellHooks = mkBefore ''
      mkdir -p ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.ensureExists)}
      echo '*' > ${lib.escapeShellArg "${cfg.data}/.gitignore"}
    '';
  };
}
