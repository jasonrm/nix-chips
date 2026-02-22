{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  inherit (pkgs.writers) makeScriptWriter;

  cfg = config.programs.rust;

  writePhp = makeScriptWriter {
    interpreter = "${pkgs.php}/bin/php";
    check = "${pkgs.php}/bin/php -l";
  };

  writePhpBin = name: writePhp "/bin/${name}";

  update-jetbrains-rust = writePhpBin "update-jetbrains-rust" ''
    <?php
    $workspaceFile = '.idea/workspace.xml';
    if (!file_exists($workspaceFile)) {
        exit;
    }

    $stdlibPath = getenv('RUST_STD_LIB');
    $toolchainBin = getenv('RUST_TOOLCHAIN_BIN');

    $doc = new DOMDocument;
    $doc->preserveWhiteSpace = false;
    $doc->formatOutput = true;
    $doc->load($workspaceFile);

    $xpath = new DOMXPath($doc);

    // Helper: find or create a component by name
    function findOrCreateComponent(DOMDocument $doc, DOMXPath $xpath, string $name): DOMElement {
        $nodes = $xpath->query("//component[@name='$name']");
        if ($nodes->length === 0) {
            $component = $doc->createElement('component');
            $component->setAttribute('name', $name);
            $doc->documentElement->appendChild($component);
        } else {
            $component = $nodes->item(0);
        }
        return $component;
    }

    // Helper: find or create <option name="..." value="...">
    function upsertOption(DOMDocument $doc, DOMXPath $xpath, DOMElement $parent, string $name, string $value): void {
        $nodes = $xpath->query("option[@name='$name']", $parent);
        if ($nodes->length === 0) {
            $option = $doc->createElement('option');
            $option->setAttribute('name', $name);
            $parent->appendChild($option);
        } else {
            $option = $nodes->item(0);
        }
        $option->setAttribute('value', $value);
    }

    // Find or create CargoProjects component with project entry
    $cargo = findOrCreateComponent($doc, $xpath, 'CargoProjects');
    $cargoProjects = $xpath->query("cargoProject[@FILE='\$PROJECT_DIR\$/Cargo.toml']", $cargo);
    if ($cargoProjects->length === 0) {
        $cargoProject = $doc->createElement('cargoProject');
        $cargoProject->setAttribute('FILE', '$PROJECT_DIR$/Cargo.toml');
        $cargo->appendChild($cargoProject);
    }

    // Find or create RustProjectSettings component
    $component = findOrCreateComponent($doc, $xpath, 'RustProjectSettings');
    upsertOption($doc, $xpath, $component, 'explicitPathToStdlib', $stdlibPath);
    upsertOption($doc, $xpath, $component, 'toolchainHomeDirectory', $toolchainBin);

    $doc->save($workspaceFile);
  '';

  toolchain-with-path = pkgs.stdenv.mkDerivation {
    pname = "toolchain-with-path";
    version = "0.1.0";
    dontUnpack = true;
    nativeBuildInputs = [pkgs.makeWrapper];
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
          pkgs.cargo-outdated
          pkgs.cargo-udeps
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
        default =
          if config.dir.project != "/dev/null"
          then config.dir.project
          else null;
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
        desc = "Build the project";
        cmds = ["${cfg.toolchainOutput}/bin/cargo build"];
      };
      check-cargo = {
        dir = cfg.workingDirectory;
        desc = "Run tests";
        cmds = ["${cfg.toolchainOutput}/bin/cargo check"];
      };
      update-cargo = {
        dir = cfg.workingDirectory;
        desc = "Update dependencies";
        cmds = ["${cfg.toolchainOutput}/bin/cargo update"];
      };

      check.deps = ["check-cargo"];
      update.deps = ["update-cargo"];
      build.deps = ["build-cargo"];
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
      nativeBuildInputs = [toolchain-with-path];
      contents = [pkgs.libiconv];
      environment = [
        "RUST_TOOLCHAIN_BIN=${cfg.toolchain}/bin"
        "RUST_STD_LIB=${cfg.standardLibraryOutput}"
      ];
      shellHooks = ''
        echo RUST_TOOLCHAIN_BIN $RUST_TOOLCHAIN_BIN
        echo RUST_STD_LIB       $RUST_STD_LIB
        ${update-jetbrains-rust}/bin/update-jetbrains-rust
      '';
    };
  };
}
