{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib;
let
  inherit (pkgs) writeText;
  inherit (pkgs.writers) writeBashBin;
  inherit (chips.lib.traefik) hostRegexp;

  cfg = config.programs.phpApp;
  phpfpm = config.services.phpfpm.pools.default;
  phpfpmWithSpx = config.services.phpfpm.pools.spx;
  phpfpmWithXdebug = config.services.phpfpm.pools.xdebug;
  phpfpmWithExcimer = config.services.phpfpm.pools.excimer;
  phpfpmWithPcov = config.services.phpfpm.pools.pcov;

  nginx = config.services.nginx;

  phpBase = cfg.php.pkg.buildEnv { inherit (cfg.php) extensions extraConfig; };

  phpWithSpx = cfg.php.pkg.buildEnv {
    extraConfig = ''
      ${cfg.php.extraConfig}
      spx.data_dir=${config.dir.data}/spx
      spx.http_enabled=1
      spx.http_key=A3F6E538
      spx.http_ip_whitelist=*
    '';
    extensions =
      f:
      (concatMap (exts: exts f) [
        cfg.php.extensions
        ({ all, ... }: [ all.spx ])
      ]);
  };

  phpWithXdebug = cfg.php.pkg.buildEnv {
    extraConfig = ''
      ${cfg.php.extraConfig}
      xdebug.mode=debug
      xdebug.start_with_request=trigger
    '';
    extensions =
      f:
      (concatMap (exts: exts f) [
        cfg.php.extensions
        ({ all, ... }: [ all.xdebug ])
      ]);
  };

  phpWithExcimer = cfg.php.pkg.buildEnv {
    inherit (cfg.php) extraConfig;
    extensions =
      f:
      (concatMap (exts: exts f) [
        cfg.php.extensions
        ({ all, ... }: [ all.excimer ])
      ]);
  };

  # auto_prepend_file=${../php-pcov/entry.php}
  phpWithPcov = cfg.php.pkg.buildEnv {
    extraConfig = ''
      ${cfg.php.extraConfig}
      pcov.enabled=1
      pcov.directory=${config.dir.project}
      pcov.exclude="~(vendor|tests|node_modules)~"
    '';
    extensions =
      f:
      (concatMap (exts: exts f) [
        cfg.php.extensions
        ({ all, ... }: [ all.pcov ])
      ]);
  };

  php-pcov = writeBashBin "php-pcov" ''
    exec ${phpWithPcov}/bin/php $*
  '';

  php-eximer-entry = writeText "php-eximer-entry.php" ''
    <?php
    (function () {
      if (isset($_ENV['SENTRY_DSN']) && $_ENV['SENTRY_DSN']) {
        require_once './vendor/autoload.php';
        \Sentry\init([
            'dsn' => $_ENV['SENTRY_DSN'],
            'traces_sample_rate' => (float) $_ENV['SENTRY_TRACES_SAMPLE_RATE'],
            'profiles_sample_rate' => (float) $_ENV['SENTRY_PROFILES_SAMPLE_RATE'],
            'environment' => $_ENV['SENTRY_ENVIRONMENT'],
        ]);
        $name = implode('.', array_slice($_SERVER['argv'] ?? ['unknown'], 0, 2));
        $name = str_replace(':', '.', $name);
        $tx = \Sentry\startTransaction(new \Sentry\Tracing\TransactionContext($name));
        register_shutdown_function(fn () => $tx->finish());
      }
    })();
  '';

  php-excimer = writeBashBin "php-excimer" ''
    exec ${phpWithExcimer}/bin/php -d auto_prepend_file=${php-eximer-entry} $*
  '';

  pcov-report = writeBashBin "pcov-report" ''
    cd ${config.dir.project}
  '';
  # exec ${phpWithPcov}/bin/php ${../php-pcov/report.php} $*
in
{
  options = with types; {
    programs.phpApp = {
      enable = mkEnableOption (mdDoc "Enable PHP-FPM App");

      publicDir = mkOption {
        type = str;
        default = "${config.dir.project}/public";
      };

      virtualHost = mkOption {
        type = submodule (import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix");
        default = {
          serverName = "frontend";
        };
      };

      php = {
        pkg = mkOption {
          type = package;
          default = pkgs.php;
        };
        extensions = mkOption {
          type = functionTo (listOf package);
          default =
            { enabled, all, ... }:
            with all;
            enabled
            ++ [
              memcached
              imagick
              igbinary
              redis
            ];
        };
        extraConfig = mkOption {
          type = lines;
          default = "";
        };
      };

      poolConfig = mkOption {
        type = attrsOf (oneOf [
          str
          int
          bool
        ]);
        default = {
          "pm" = "static";
          "pm.max_children" = 4;
        };
        description = mdDoc ''
          Options for the PHP pool. See the documentation on `php-fpm.conf`
          for details on configuration directives.
        '';
      };

      phpEnv = mkOption {
        type = attrsOf (oneOf [
          str
          int
          bool
        ]);
        default = {};
      };
    };
  };

  config = mkIf cfg.enable {
    programs.php = {
      enable = true;
      inherit (cfg.php) pkg extensions extraConfig;
    };
    devShell = {
      contents = [
        php-pcov
        pcov-report
        php-excimer
      ];
    };
    services.phpfpm.pools.default = {
      user = "";
      group = "";
      phpPackage = phpBase;
      phpEnv = cfg.phpEnv;
      settings = cfg.poolConfig;
      listen = "${config.dir.data}/phpfpm-default.sock";
    };

    services.phpfpm.pools.spx = {
      user = "";
      group = "";
      phpPackage = phpWithSpx;
      phpEnv = cfg.phpEnv;
      settings = cfg.poolConfig;
      listen = "${config.dir.data}/phpfpm-spx.sock";
    };

    services.phpfpm.pools.xdebug = {
      user = "";
      group = "";
      phpPackage = phpWithXdebug;
      phpEnv = cfg.phpEnv;
      settings = cfg.poolConfig;
      listen = "${config.dir.data}/phpfpm-xdebug.sock";
    };

    services.phpfpm.pools.excimer = {
      user = "";
      group = "";
      phpPackage = phpWithExcimer;
      phpEnv = cfg.phpEnv;
      settings = cfg.poolConfig;
      listen = "${config.dir.data}/phpfpm-excimer.sock";
    };

    services.phpfpm.pools.pcov = {
      user = "";
      group = "";
      phpPackage = phpWithPcov;
      phpEnv = cfg.phpEnv;
      settings = cfg.poolConfig;
      listen = "${config.dir.data}/phpfpm-pcov.sock";
    };

    services.traefik = {
      routers = {
        frontend = {
          service = "nginx";
          priority = 1;
          rule = "Host(`frontend.${config.project.domainSuffix}`)";
        };
      };
      services = {
        nginx = {
          loadBalancer.servers = [
            { url = "http://127.0.0.1:${toString config.services.nginx.defaultHTTPListenPort}"; }
          ];
        };
      };
    };

    services.nginx = {
      enable = true;
      appendHttpConfig = ''
        map $http_cookie $cookie_backend {
            default               default;
            "~*EXCIMER_ENABLED="  excimer;
            "~*XDEBUG_PROFILE="   excimer;
            "~*XDEBUG_SESSION="   xdebug;
            "~*XDEBUG_TRACE="     pcov;
            "~*SPX_"              spx;
        }

        map $http_cookie $log_level {
            default               warning;
            "~*XDEBUG_TRACE="     debug;
        }

        map $http_cookie $log_stack_trace_enabled {
            default               "";
            "~*XDEBUG_TRACE="     true;
        }

        map $arg_SPX_UI_URI $arg_backend {
            default               default;
            "~.+"                 spx;
        }

        map $cookie_backend $sentry_sample_rate {
            default               "";
            excimer               "1.0";
        }

        map $cookie_backend:$arg_backend $fastcgi_backend {
            "~pcov:*"             unix:${phpfpmWithPcov.socket};
            "~excimer:*"          unix:${phpfpmWithExcimer.socket};
            "~xdebug:*"           unix:${phpfpmWithXdebug.socket};
            "~spx:*"              unix:${phpfpmWithSpx.socket};
            "~*:spx"              unix:${phpfpmWithSpx.socket};
            default               unix:${phpfpm.socket};
        }
      '';
      virtualHosts.${cfg.virtualHost.serverName} =
        cfg.virtualHost
        // (optionalAttrs config.programs.lego.enable {
          onlySSL = true;
          sslCertificate = config.programs.lego.certFile;
          sslCertificateKey = config.programs.lego.keyFile;
        })
        // {
          root = cfg.publicDir;
          extraConfig = ''
            charset UTF-8;
            index index.php index.html;

            keepalive_timeout 1d;
            send_timeout 1d;
            client_body_timeout 1d;
            client_header_timeout 1d;
            proxy_connect_timeout 1d;
            proxy_read_timeout 1d;
            proxy_send_timeout 1d;
            fastcgi_connect_timeout 1d;
            fastcgi_read_timeout 1d;
            fastcgi_send_timeout 1d;
            memcached_connect_timeout 1d;
            memcached_read_timeout 1d;
            memcached_send_timeout 1d;
          '';
          locations = {
            "/".extraConfig = ''
              try_files $uri /index.php?$query_string;
            '';

            "/coverage/".extraConfig = ''
              alias ${config.dir.data}/pcov/html/;
              try_files $uri /index.html;
            '';

            "~ \\.php$".extraConfig = ''
              include ${nginx.package}/conf/fastcgi.conf;
              include ${nginx.package}/conf/fastcgi_params;

              fastcgi_buffering off;
              fastcgi_index index.php;
              fastcgi_split_path_info ^(.+\.php)(/.+)$;
              fastcgi_param SERVER_NAME $http_host;
              fastcgi_param SCRIPT_FILENAME $request_filename;
              fastcgi_param PATH_INFO $fastcgi_path_info;

              # pcov shenanigans
              fastcgi_param NIX_CHIPS_DIR_DATA ${config.dir.data};

              # Per-request configuration
              fastcgi_param FASTCGI_BACKEND $fastcgi_backend;
              fastcgi_param LOG_LEVEL $log_level;
              fastcgi_param LOG_STACK_TRACE_ENABLED $log_stack_trace_enabled;
              fastcgi_param SENTRY_TRACES_SAMPLE_RATE $sentry_sample_rate;
              fastcgi_param SENTRY_PROFILES_SAMPLE_RATE $sentry_sample_rate;

              fastcgi_pass $fastcgi_backend;

            '';
          };
        };
    };
  };
}
