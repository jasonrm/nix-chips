{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  inherit (pkgs.writers) writeBashBin makeScriptWriter;
  inherit (pkgs) terraform symlinkJoin mkShell;

  writePhp = makeScriptWriter {
    interpreter = "${pkgs.php}/bin/php";
    check = "${pkgs.php}/bin/php -l";
  };

  cfg = config.programs.php;

  flamegraph = writeBashBin "flamegraph-php" ''
    ${cfg.pkg}/bin/php ${pkgs.flamegraph.src}/stackcollapse-xdebug.php $1 | ${pkgs.flamegraph}/bin/flamegraph.pl > $2
  '';

  php-xdebug = writeBashBin "php-xdebug" ''
    ${cfg.pkg}/bin/php \
      -d zend_extension=${cfg.pkg.extensions.xdebug}/lib/php/extensions/xdebug.so \
      -d xdebug.start_with_request=yes \
      -d xdebug.mode=debug \
      $*
  '';

  php-spx = writeBashBin "php-spx" ''
    SPX_ENABLED=1 ${cfg.pkg}/bin/php \
      -d extension=${cfg.pkg.extensions.spx}/lib/php/extensions/spx.so \
      $*
  '';

  php = cfg.pkg.buildEnv {
    inherit (cfg) extraConfig extensions;
  };

  updatePhpWorkspaceProjectConfiguration = writePhp "updatePhpWorkspaceProjectConfiguration" ''
    <?php
    if (!file_exists('.idea/workspace.xml')) {
      return;
    }
    $doc = new DOMDocument;
    $doc->load('.idea/workspace.xml');

    $xpath = new DOMXPath($doc);
    $query = '//component[@name="PhpWorkspaceProjectConfiguration"]';

    $entries = $xpath->query($query);
    foreach ($entries as $entry) {
        $entry->setAttribute('interpreter_name', '${pkgs.php}/bin/php');
    }

    $nodes = $xpath->query("//component[@name='ComposerSettings']/execution/executable");
    foreach ($nodes as $node) {
        $node->setAttribute("path", '${php.packages.composer}/bin/composer');
    }

    $doc->save('.idea/workspace.xml');
  '';
in {
  options = with lib.types; {
    programs.php = {
      enable = mkEnableOption "PHP support";

      pkg = mkOption {
        type = package;
        default = pkgs.php;
      };

      env = mkOption {
        type = package;
        readOnly = true;
        default = php;
      };

      extensions = mkOption {
        type = functionTo (listOf package);
        default = {
          enabled,
          all,
          ...
        }:
          with all; enabled ++ [];
      };

      extraConfig = mkOption {
        type = lines;
        default = "";
      };
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      shellHooks = ''
        ${updatePhpWorkspaceProjectConfiguration}
        echo php: ${php}/bin/php
      '';
      environment = let
        projectDir =
          if config.dir.project != "/dev/null"
          then config.dir.project
          else "$PWD";
      in [
        "PATH=$PATH:${projectDir}/vendor/bin"
      ];
      contents = [
        flamegraph
        # php-spx
        php-xdebug
        php
        php.packages.composer
      ];
    };

    #    outputs.apps.php = {
    #      program = "${php}/bin/php";
    #    };
    #    outputs.apps.flamegraph-php = {
    #      program = "${flamegraph}/bin/flamegraph-php";
    #    };
    #    outputs.apps.php-xdebug = {
    #      program = "${php-xdebug}/bin/php-xdebug";
    #    };
    #    outputs.apps.php-spx = {
    #      program = "${php-spx}/bin/php-spx";
    #    };
  };
}
