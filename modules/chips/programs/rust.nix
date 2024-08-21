{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.rust;

  toolchain-with-path = pkgs.stdenv.mkDerivation {
    pname = "toolchain-with-path";
    version = "0.1.0";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.makeWrapper
    ];
    installPhase = ''
      mkdir -p $out/bin
      ln -s ${cfg.toolchain}/bin/* $out/bin/
      for i in $out/bin/*; do
          wrapProgram "$i" --prefix PATH : ${lib.makeBinPath [cfg.toolchain]}
      done
    '';
  };
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
        toolchain-with-path
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
