{
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
      mkdir -p $out
      ln -s ${cfg.toolchain}/* $out/
      rm $out/bin
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

      contents = mkOption {
        type = listOf package;
        default = [
          pkgs.rustc
          pkgs.cargo
          pkgs.cargo-sort
          pkgs.rustfmt
          pkgs.cargo-watch
          pkgs.rust-analyzer
        ];
        description = "Additional packages to include in the dev shell";
      };

      toolchain = mkOption {
        type = package;
        default = pkgs.symlinkJoin {
          name = "rust-toolchain";
          paths = config.programs.rust.contents;
        };
        description = "The rust toolchain to use";
      };

      toolchainOutput = mkOption {
        type = package;
        default = toolchain-with-path;
        readOnly = true;
      };

      standardLibraryOutput = mkOption {
        type = oneOf [
          package
          path
        ];
        default = pkgs.rustPlatform.rustLibSrc;
        readOnly = true;
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
        "RUST_TOOLCHAIN_BIN=${cfg.toolchain}/bin"
        "RUST_STD_LIB=${cfg.standardLibraryOutput}"
      ];
      shellHooks = ''
        echo RUST_TOOLCHAIN_BIN $RUST_TOOLCHAIN_BIN
        echo RUST_STD_LIB       $RUST_STD_LIB
        if [ -f .idea/workspace.xml ]; then
            echo "Updating RustProjectSettings"
            ${pkgs.xmlstarlet}/bin/xmlstarlet ed -L \
                -u 'project/component[@name="RustProjectSettings"]/option[@name="explicitPathToStdlib"]/@value' \
                -v "$RUST_STD_LIB" \
                .idea/workspace.xml
            ${pkgs.xmlstarlet}/bin/xmlstarlet ed -L \
                -u 'project/component[@name="RustProjectSettings"]/option[@name="toolchainHomeDirectory"]/@value' \
                -v "$RUST_TOOLCHAIN_BIN" \
                .idea/workspace.xml
        fi
      '';
    };
  };
}
