{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  inherit (pkgs.writers) writeBashBin;
  inherit (pkgs.stdenv) isDarwin;
  inherit (pkgs) symlinkJoin mkShell;

  cfg = config.shell;
in {
  imports = [
    # paths to other modules
  ];

  options = with lib.types; {
    shell = {
      enable = mkEnableOption "use shell";

      environment = mkOption {
        type = listOf str;
        default = [];
      };

      shellHooks = mkOption {
        type = listOf lines;
        default = [];
      };

      directories = mkOption {
        type = listOf str;
        default = [];
      };

      contents = mkOption {
        type = listOf package;
        default = [];
      };
    };
  };

  config = {
    shell.shellHooks = [
      ''
        export ${lib.concatStringsSep " " (map escapeShellArg cfg.environment)}
      ''
    ];
    outputs.devShell = pkgs.mkShell {
      buildInputs =
        cfg.contents
        ++ lib.optionals isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
          CoreServices
        ]);

      shellHook = lib.concatStringsSep "\n" cfg.shellHooks;
    };
  };
}
