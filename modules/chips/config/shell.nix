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

  cfg = config.chips.devShell;
in {
  imports = [
    # paths to other modules
  ];

  options = with lib.types; {
    chips.devShell = {
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

  config = mkIf cfg.enable {
    chips.devShell.shellHooks = [
      ''
        export ${lib.concatStringsSep " " (map escapeShellArg cfg.environment)}
      ''
    ];
    outputs.devShells.default = pkgs.mkShell {
      buildInputs =
        cfg.contents
        ++ lib.optionals isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
          CoreServices
        ]);

      shellHook = lib.concatStringsSep "\n" cfg.shellHooks;
    };
  };
}
