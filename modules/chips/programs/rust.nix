{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.programs.rust;

  toolchain-with-path = pkgs.stdenv.mkDerivation {
    pname = "toolchain-with-path";
    version = "0.1.0";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      mkdir -p $out
      ln -s ${cfg.toolchain}/* $out/
      rm $out/bin
      mkdir -p $out/bin
      ln -s ${cfg.toolchain}/bin/* $out/bin/
      for i in $out/bin/*; do
          wrapProgram "$i" --prefix PATH : ${lib.makeBinPath [ cfg.toolchain ]}
      done
    '';
  };
in
{
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
          pkgs.cargo-outdated
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

      workingDirectory = mkOption {
        type = nullOr str;
        default = if config.dir.project != "/dev/null" then config.dir.project else null;
      };
    };
  };

  config = mkIf cfg.enable {
    programs.zed.settings = {
      lsp = {
        rust-analyzer = {
          initialization_options = {
            cargo = {
              allTargets = false;
            };
          };
          binary = {
            path = "${cfg.toolchainOutput}/bin/rust-analyzer";
          };
        };
      };
    };

    programs.taskfile.enable = mkDefault true;
    programs.taskfile.config.tasks = {
      build-cargo = {
        dir = cfg.workingDirectory;
        description = "Build the project";
        cmds = [ "${cfg.toolchainOutput}/bin/cargo build" ];
      };
      check-cargo = {
        dir = cfg.workingDirectory;
        description = "Run tests";
        cmds = [ "${cfg.toolchainOutput}/bin/cargo check" ];
      };
      update-cargo = {
        dir = cfg.workingDirectory;
        description = "Update dependencies";
        cmds = [ "${cfg.toolchainOutput}/bin/cargo update" ];
      };

      check.deps = [ "check-cargo" ];
      update.deps = [ "update-cargo" ];
      build.deps = [ "build-cargo" ];
    };

    programs.lefthook.config = {
      pre-commit = {
        commands = {
          format-cargo = {
            glob = mkDefault "*.{rs}";
            run = mkDefault "${cfg.toolchainOutput}/bin/cargo fmt -- {staged_files}";
            stage_fixed = true;
            root = mkDefault cfg.workingDirectory;
          };
          check-cargo = {
            glob = mkDefault "*.{rs}";
            run = mkDefault "${cfg.toolchainOutput}/bin/cargo check";
            root = mkDefault cfg.workingDirectory;
          };
        };
      };
      pre-push = {
        commands = {
          check-cargo-fmt = {
            glob = mkDefault "*.{rs}";
            run = mkDefault "${cfg.toolchainOutput}/bin/cargo fmt --check";
            root = mkDefault cfg.workingDirectory;
          };
          check-cargo-check = {
            glob = mkDefault "*.{rs}";
            run = mkDefault "${cfg.toolchainOutput}/bin/cargo check";
            root = mkDefault cfg.workingDirectory;
          };
          check-cargo-test = {
            glob = mkDefault "{package.json,pnpm-lock.yaml}";
            run = mkDefault "${cfg.toolchainOutput}/bin/cargo test";
            root = mkDefault cfg.workingDirectory;
          };
        };
      };
    };

    devShell = {
      nativeBuildInputs = [ toolchain-with-path ];
      contents = [ pkgs.libiconv ];
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
