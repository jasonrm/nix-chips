{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  inherit (pkgs.writers) writeBashBin makeScriptWriter;
  inherit (pkgs) terraform symlinkJoin mkShell;

  cfg = config.programs.php;

  phpEnv = cfg.pkg.buildEnv { inherit (cfg) extraConfig extensions; };

  extendExtensions = baseFn: additional: { ... }@args: (baseFn args) ++ additional;

  phpDebugEnv = cfg.pkg.buildEnv {
    extraConfig = ''
      ${cfg.extraConfig}

      # xdebug
      xdebug.mode=debug
      xdebug.start_with_request=yes
      ${cfg.xdebug.extraConfig}
    '';
    extensions = extendExtensions cfg.extensions [ cfg.pkg.extensions.xdebug ];
  };
  phpSpxEnv = cfg.pkg.buildEnv {
    extraConfig = ''
      ${cfg.extraConfig}

      # spx
      spx.http_enabled=1
      spx.http_key="dev"
      spx.http_ip_whitelist="127.0.0.1"
      ${cfg.spx.extraConfig}
    '';
    extensions = extendExtensions cfg.extensions [ cfg.pkg.extensions.spx ];
  };

  writePhp = makeScriptWriter {
    interpreter = "${phpEnv}/bin/php";
    check = "${phpEnv}/bin/php -l";
  };

  writePhpBin = name: writePhp "/bin/${name}";

  flamegraph = writeBashBin "flamegraph-php" ''
    ${cfg.pkg}/bin/php ${pkgs.flamegraph.src}/stackcollapse-xdebug.php $1 | ${pkgs.flamegraph}/bin/flamegraph.pl > $2
  '';

  php-xdebug = writeBashBin "php-xdebug" ''
    ${phpDebugEnv}/bin/php $*
  '';

  php-spx = writeBashBin "php-spx" ''
    export SPX_ENABLED=''${SPX_ENABLED:-1}
    export SPX_REPORT=''${SPX_REPORT:-full}
    ${phpSpxEnv}/bin/php $*
  '';

  update-jetbrains = writePhpBin "update-jetbrains" ''
    <?php
    if (!file_exists('.idea/workspace.xml') || !file_exists('.idea/php.xml')) {
        exit;
    }

    // UUID from PHP path
    $pathHash = md5("${phpEnv}");
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
        $node->setAttribute("path", '${phpEnv.packages.composer}/bin/composer');
    }

    $doc->save('.idea/workspace.xml');

    $doc = new DOMDocument;
    $doc->load('.idea/php.xml');
    $xpath = new DOMXPath($doc);
    $nodes = $xpath->query("//component[@name='PhpInterpreters']");
        $interpreter = $doc->createElement('interpreter');
        $interpreter->setAttribute('id', $pathUUID);
        $interpreter->setAttribute('name', $interpreterName);
        $interpreter->setAttribute('home', "${phpEnv}/bin/php");
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
in
{
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
        default = phpEnv;
      };

      extensions = mkOption {
        type = functionTo (listOf package);
        default = { enabled, all, ... }: with all; enabled ++ [ ];
      };

      extraConfig = mkOption {
        type = lines;
        default = "";
      };

      php-cs-fixer = {
        filename = mkOption {
          type = str;
          default = ".php-cs-fixer.dist.php";
        };
        addToGitIgnore = mkOption {
          type = bool;
          default = false;
        };
      };

      xdebug = {
        env = mkOption {
          type = package;
          readOnly = true;
          default = phpDebugEnv;
        };
        extraConfig = mkOption {
          type = lines;
          default = "";
        };
      };

      spx = {
        env = mkOption {
          type = package;
          readOnly = true;
          default = phpSpxEnv;
        };
        extraConfig = mkOption {
          type = lines;
          default = "";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    devShell = {
      shellHooks = ''
        ${update-jetbrains}/bin/update-jetbrains
      ''
      + optionalString cfg.php-cs-fixer.addToGitIgnore ''
        if [ -d .git ]; then
          if ! grep -q "^${cfg.php-cs-fixer.filename}$" .git/info/exclude; then
           echo "${cfg.php-cs-fixer.filename}" >> .git/info/exclude
          fi
        fi
      '';
      environment =
        let
          projectDir = if config.dir.project != "/dev/null" then config.dir.project else "$PWD";
        in
        [ "PATH=$PATH:$PWD/vendor/bin" ];
      contents = [
        flamegraph
        php-spx
        php-xdebug
        phpEnv
        phpEnv.packages.composer
      ];
    };

    programs.taskfile.enable = mkDefault true;
    programs.taskfile.config.tasks = {
      install-composer = {
        cmds = [ "${phpEnv.packages.composer}/bin/composer install" ];
        generates = [
          "vendor/composer/installed.json"
          "vendor/autoload.php"
        ];
        desc = "Install Composer Dependencies";
        sources = [
          "composer.json"
          "composer.lock"
        ];
      };
      update-composer = {
        cmds = [ "${phpEnv.packages.composer}/bin/composer update" ];
        desc = "Update Composer Dependencies";
      };
      check-composer = {
        cmds = [ "${phpEnv.packages.composer}/bin/composer validate --strict --no-check-all" ];
        preconditions = [ "test -f composer.json" ];
        generates = [ "composer.lock" ];
        desc = "Check Composer Lock File";
        sources = [ "composer.json" ];
      };

      format-php-cs-fixer = {
        cmds = [
          "${phpEnv}/bin/php ./vendor/bin/php-cs-fixer fix --config ${cfg.php-cs-fixer.filename} {{.CLI_ARGS}}"
        ];
        preconditions = [ "test -f ${cfg.php-cs-fixer.filename}" ];
        deps = [ "install-composer" ];
        desc = "Format PHP files with PHP-CS-Fixer";
      };
      check-php-cs-fixer = {
        cmds = [
          "${phpEnv}/bin/php ./vendor/bin/php-cs-fixer fix --config ${cfg.php-cs-fixer.filename} --dry-run {{.CLI_ARGS}}"
        ];
        preconditions = [ "test -f ${cfg.php-cs-fixer.filename}" ];
        deps = [ "install-composer" ];
        desc = "Check PHP files with PHP-CS-Fixer";
      };

      check-phpstan = {
        cmds = [ "${phpEnv}/bin/php ./vendor/phpstan/phpstan/phpstan.phar --memory-limit=4G analyse" ];
        preconditions = [ "test -f phpstan.neon" ];
        deps = [ "install-composer" ];
        desc = "Check PHP files with PHPStan";
      };

      check-psalm = {
        cmds = [ "${cfg.pkg}/bin/php ./vendor/bin/psalm --config=psalm.xml --memory-limit=8G" ];
        preconditions = [ "test -f psalm.xml" ];
        deps = [ "install-composer" ];
        desc = "Check PHP files with Psalm";
      };

      check.deps = [
        "check-php-cs-fixer"
        "check-phpstan"
        "check-psalm"
        "check-composer"
      ];
      format.deps = [ "format-php-cs-fixer" ];
      install.deps = [ "install-composer" ];
      update.deps = [ "update-composer" ];
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
  };
}
