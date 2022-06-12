{ lib, pkgs, config, ... }:
let
  inherit (lib) mkOption;
  cfg = config.dir;
in
{
  imports = [
  ];

  options = with lib.types; {
    dir = {
      root = mkOption {
        type = str;
        default = "/usr/local";
      };

      log = mkOption {
        type = str;
        readOnly = true;
        default = "${cfg.root}/var/log";
      };

      run = mkOption {
        type = str;
        readOnly = true;
        default = "${cfg.root}/var/run";
      };

      lib = mkOption {
        type = str;
        readOnly = true;
        default = "${cfg.root}/lib";
      };

      ensureExists = mkOption {
        type = listOf str;
        default = [ ];
      };
    };
  };

  config = {
    dir.ensureExists = [
      cfg.root
      cfg.log
      cfg.run
      cfg.lib
    ];
    shell.shellHooks = [
      ''
        mkdir -p ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.ensureExists)}
      ''
    ];
  };
}
