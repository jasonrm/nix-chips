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

      toolchain = mkOption {
        type = package;
        default = pkgs.symlinkJoin {
          name = "rust-toolchain";
          paths = [
            pkgs.rustc
            pkgs.cargo
            pkgs.cargo-sort
            pkgs.rustfmt
            pkgs.cargo-watch
            pkgs.rust-analyzer
            pkgs.rustPlatform.rustcSrc
          ];
        };
        description = "The rust toolchain to use";
      };
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      nativeBuildInputs = [
        cfg.toolchain
      ];
      contents = [
        pkgs.libiconv
      ];
      environment = [
        "RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}"
      ];
    };
  };
}
