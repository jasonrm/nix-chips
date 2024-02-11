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

  writePhpBin = name:
    writePhp "/bin/${name}";

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

  update-jetbrains = writePhpBin "update-jetbrains" ''
    <?php
    if (!file_exists('.idea/workspace.xml') || !file_exists('.idea/php.xml')) {
        exit;
    }

    // UUID from PHP path
    $pathHash = md5("${pkgs.php}");
    $chunks = [
        substr($pathHash, 0, 8),
        substr($pathHash, 8, 4),
        substr($pathHash, 12, 4),
        substr($pathHash, 16, 4),
        substr($pathHash, 20, 12)
    ];
    $pathUUID = implode('-', $chunks);
    $phpVersion = phpversion();
    $interpreterName = "Project PHP $phpVersion (" . substr($pathHash, 0, 8) . ")";

    $doc = new DOMDocument;
    $doc->load('.idea/workspace.xml');

    $xpath = new DOMXPath($doc);
    $query = '//component[@name="PhpWorkspaceProjectConfiguration"]';

    $entries = $xpath->query($query);
    foreach ($entries as $entry) {
        $entry->setAttribute('interpreter_name', $interpreterName);
    }
    $nodes = $xpath->query("//component[@name='ComposerSettings']/execution/executable");
    foreach ($nodes as $node) {
        $node->setAttribute("path", '${php.packages.composer}/bin/composer');
    }

    $doc->save('.idea/workspace.xml');

    $doc = new DOMDocument;
    $doc->load('.idea/php.xml');
    $xpath = new DOMXPath($doc);
    $nodes = $xpath->query("//component[@name='PhpInterpreters']");
        $interpreter = $doc->createElement('interpreter');
        $interpreter->setAttribute('id', $pathUUID);
        $interpreter->setAttribute('name', $interpreterName);
        $interpreter->setAttribute('home', "${pkgs.php}/bin/php");
        $interpreter->setAttribute('auto', 'true');
        $interpreter->setAttribute('debugger_id', 'php.debugger.XDebug');

        if ($nodes->length === 0) {
            $interpreters = $doc->createElement('interpreters');
            $interpreters->appendChild($interpreter);
            $component = $doc->createElement('component');
            $component->setAttribute('name', 'PhpInterpreters');
            $component->appendChild($interpreters);
            $doc->documentElement->appendChild($component);
        } else {
            $interpreters = $nodes->item(0)->getElementsByTagName('interpreters')->item(0);
            $interpreters->nodeValue = "";
            $interpreters->appendChild($interpreter);
        }
        // Find and delete PhpInterpretersPhpInfoCache
        $nodes = $xpath->query("//component[@name='PhpInterpretersPhpInfoCache']");
        foreach ($nodes as $node) {
            $node->parentNode->removeChild($node);
        }

        $doc->save('.idea/php.xml');
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

  config = mkIf cfg.enable {
    devShell = {
      shellHooks = ''
        ${update-jetbrains}/bin/update-jetbrains
      '';
      environment = let
        projectDir =
          if config.dir.project != "/dev/null"
          then config.dir.project
          else "$PWD";
      in [
        "PATH=$PATH:$PWD/vendor/bin"
      ];
      contents = [
        flamegraph
        # php-spx
        php-xdebug
        php
        php.packages.composer
      ];
    };

    programs.taskfile.config.tasks = {
      install-composer = {
        cmds = ["${pkgs.php.packages.composer}/bin/composer install"];
        generates = ["vendor/composer/installed.json" "vendor/autoload.php"];
        desc = "Install Composer Dependencies";
        sources = ["composer.json" "composer.lock"];
      };
      update-composer = {
        cmds = ["${pkgs.php.packages.composer}/bin/composer update"];
        desc = "Update Composer Dependencies";
        sources = ["composer.json"];
      };
      check-composer = {
        cmds = ["${pkgs.php.packages.composer}/bin/composer validate --strict --no-check-all"];
        generates = ["composer.lock"];
        desc = "Update Composer Dependencies";
        sources = ["composer.json"];
      };

      format-php-cs-fixer = {
        cmds = ["${pkgs.php}/bin/php ./vendor/bin/php-cs-fixer fix --config .php-cs-fixer.php {{.CLI_ARGS}}"];
        preconditions = [
          "test -f .php-cs-fixer.php"
        ];
        desc = "Format PHP files with PHP-CS-Fixer";
      };
      check-php-cs-fixer = {
        cmds = ["${pkgs.php}/bin/php ./vendor/bin/php-cs-fixer fix --config .php-cs-fixer.php --dry-run {{.CLI_ARGS}}"];
        preconditions = [
          "test -f .php-cs-fixer.php"
        ];
        desc = "Check PHP files with PHP-CS-Fixer";
      };

      check-phpstan = {
        cmds = ["${pkgs.php}/bin/php ./vendor/bin/phpstan analyse"];
        preconditions = [
          "test -f phpstan.neon"
        ];
        desc = "Check PHP files with PHPStan";
      };

      check.deps = ["check-php-cs-fixer" "check-phpstan" "check-composer"];
      format.deps = ["format-php-cs-fixer"];
      install.deps = ["install-composer"];
      update.deps = ["update-composer"];
    };

    programs.lefthook.config = {
      pre-commit.commands = {
        format-php-cs-fixer = {
          glob = mkDefault "*.php";
          run = mkDefault "${pkgs.go-task}/bin/task format-php-cs-fixer -- {staged_files}";
          stage_fixed = true;
        };
      };
      pre-push.commands = {
        check-composer = {
          glob = mkDefault "composer.{json,lock}";
          run = mkDefault "${pkgs.go-task}/bin/task check-composer";
        };
        check-phpstan = {
          glob = mkDefault "*.php";
          run = mkDefault "${pkgs.go-task}/bin/task check-phpstan";
        };
        check-php-cs-fixer = {
          glob = mkDefault "*.php";
          run = mkDefault "${pkgs.go-task}/bin/task check-php-cs-fixer";
        };
      };
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
