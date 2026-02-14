{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib; let
  inherit (pkgs) writeText;
  inherit (pkgs.writers) writeBashBin;
  inherit (chips.lib.traefik) hostRegexp;
  inherit (lib.lists) head drop;

  cfg = config.services.php;
  isAnyInstanceEnabled = foldl (x: y: x || y) false (mapAttrsToList (name: instance: instance.enable) cfg.instances);

  nginx = config.services.nginx;

  moduleOptions = {name, ...}: let
    opts = cfg.instances.${name};
  in {
    options = with types; {
      enable = mkEnableOption (mdDoc "Enable this PHP app instance");

      domains = mkOption {
        type = listOf str;
        default = ["${name}.${config.project.domainSuffix}"];
        description = mdDoc "List of domains for this instance.";
      };

      serverName = mkOption {
        type = str;
        default = lib.lists.head opts.domains;
        description = mdDoc "Server name for the virtual host.";
      };

      serverAliases = mkOption {
        type = listOf str;
        default = drop 1 opts.domains;
        description = mdDoc "Server aliases for the virtual host.";
      };

      publicDir = mkOption {
        type = str;
        default = "${config.dir.project}/${name}/public";
        description = mdDoc "Public directory for the app.";
      };

      dataDir = mkOption {
        type = path;
        default = "${config.dir.data}/php/${name}";
        description = mdDoc "Data directory for the instance.";
      };

      runDir = mkOption {
        type = path;
        default = "${config.dir.data}/run/php/${name}";
        description = mdDoc "Run directory for the instance.";
      };

      envFiles = mkOption {
        type = listOf path;
        default = [];
        description = mdDoc "List of environment files.";
      };

      php = {
        pkg = mkOption {
          type = package;
          default = pkgs.php;
          description = mdDoc "PHP package to use.";
        };
        extensions = mkOption {
          type = functionTo (listOf package);
          default = {
            enabled,
            all,
            ...
          }:
            with all;
              enabled
              ++ [
                memcached
                imagick
                igbinary
                redis
              ];
          description = mdDoc "PHP extensions to enable.";
        };
        extraConfig = mkOption {
          type = lines;
          default = "";
          description = mdDoc "Extra PHP configuration.";
        };
      };

      poolConfig = mkOption {
        type = attrsOf (oneOf [
          str
          int
          bool
        ]);
        default = cfg.poolConfig;
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
        default = cfg.phpEnv;
        description = mdDoc "PHP environment variables.";
      };

      virtualHost = mkOption {
        type = submodule (import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix");
        default = {};
        description = mdDoc ''
          Nginx virtual host configuration.
        '';
      };
    };
  };
in {
  options = with types; {
    services.php = {
      user = mkOption {
        type = str;
        default = "";
      };

      group = mkOption {
        type = str;
        default = "";
      };

      poolSocketUser = mkOption {
        type = str;
        default = cfg.user;
      };

      poolSocketGroup = mkOption {
        type = str;
        default = cfg.group;
      };

      php = mkOption {
        type = submodule {
          options = {
            pkg = mkOption {
              type = package;
              default = pkgs.php;
              description = mdDoc "PHP package to use.";
            };
            extensions = mkOption {
              type = functionTo (listOf package);
              default = {
                enabled,
                all,
                ...
              }:
                with all;
                  enabled
                  ++ [
                    memcached
                    imagick
                    igbinary
                    redis
                  ];
              description = mdDoc "PHP extensions.";
            };
            extraConfig = mkOption {
              type = lines;
              default = "";
              description = mdDoc "Extra PHP configuration.";
            };
          };
        };
        description = mdDoc "Global PHP options.";
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
          Global options for the PHP pool. See the documentation on `php-fpm.conf`
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
        description = mdDoc "Global PHP environment variables.";
      };

      instances = mkOption {
        type = attrsOf (submodule moduleOptions);
        default = {};
        description = mdDoc "PHP app instances.";
      };
    };
  };

  config = lib.mkIf isAnyInstanceEnabled (mkMerge [
    {
      services.phpfpm.pools = mkMerge (
        mapAttrsToList (
          name: opts:
            if opts.enable
            then let
              baseListenSettings = {
                "listen.owner" = cfg.poolSocketUser;
                "listen.group" = cfg.poolSocketGroup;
              };

              baseSettings = cfg.poolConfig // baseListenSettings // opts.poolConfig;

              phpEnv = cfg.phpEnv // opts.phpEnv;

              mkPool = variant: {
                extraConfig,
                extensions ? null,
                extraSettings ? {},
              }: {
                user = cfg.user;
                group = cfg.group;
                phpPackage = opts.php.pkg.buildEnv {
                  extraConfig = extraConfig;
                  extensions =
                    if extensions == null
                    then opts.php.extensions
                    else extensions;
                };
                inherit phpEnv;
                settings = baseSettings // extraSettings;
                listen = "${opts.runDir}/${variant}.sock";
              };

              defaultPool = mkPool "default" {
                extraConfig = opts.php.extraConfig;
                extraSettings = {
                  "pm" = "static";
                  "pm.max_children" = 4;
                  "php_admin_value[spx.data_dir]" = "${opts.dataDir}/spx";
                };
              };

              spxPool = mkPool "spx" {
                extraConfig = ''
                  ${opts.php.extraConfig}
                  spx.data_dir=${opts.dataDir}/spx
                  spx.http_enabled=1
                  spx.http_key=A3F6E538
                  spx.http_ip_whitelist=*
                '';
                extensions = f:
                  concatMap (exts: exts f) [
                    opts.php.extensions
                    ({all, ...}: optional (all ? spx) all.spx)
                  ];
              };

              xdebugPool = mkPool "xdebug" {
                extraConfig = ''
                  ${opts.php.extraConfig}
                  xdebug.mode=debug
                  xdebug.start_with_request=trigger
                '';
                extensions = f:
                  concatMap (exts: exts f) [
                    opts.php.extensions
                    ({all, ...}: optional (all ? xdebug) all.xdebug)
                  ];
              };

              excimerPool = mkPool "excimer" {
                extraConfig = opts.php.extraConfig;
                extensions = f:
                  concatMap (exts: exts f) [
                    opts.php.extensions
                    ({all, ...}: optional (all ? excimer) all.excimer)
                  ];
              };

              pcovPool = mkPool "pcov" {
                extraConfig = ''
                  ${opts.php.extraConfig}
                  pcov.enabled=1
                  pcov.directory=${config.dir.project}
                  pcov.exclude="~(vendor|tests|node_modules)~"
                '';
                extensions = f:
                  concatMap (exts: exts f) [
                    opts.php.extensions
                    ({all, ...}: optional (all ? pcov) all.pcov)
                  ];
              };
            in {
              "${name}-default" = defaultPool;
              "${name}-spx" = spxPool;
              "${name}-xdebug" = xdebugPool;
              "${name}-excimer" = excimerPool;
              "${name}-pcov" = pcovPool;
            }
            else {}
        )
        cfg.instances
      );
    }
    {
      services.nginx = mkMerge [
        {
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

            map $cookie_backend:$arg_backend:$instance $fastcgi_backend {
                ${concatStringsSep "\n" (
              flatten (
                mapAttrsToList (
                  name: opts:
                    if opts.enable
                    then [
                      "default:default:${name} unix:${config.services.phpfpm.pools."${name}-default".socket};"
                      "default:spx:${name} unix:${config.services.phpfpm.pools."${name}-spx".socket};"
                      "excimer:default:${name} unix:${config.services.phpfpm.pools."${name}-excimer".socket};"
                      "excimer:spx:${name} unix:${config.services.phpfpm.pools."${name}-excimer".socket};"
                      "xdebug:default:${name} unix:${config.services.phpfpm.pools."${name}-xdebug".socket};"
                      "xdebug:spx:${name} unix:${config.services.phpfpm.pools."${name}-xdebug".socket};"
                      "pcov:default:${name} unix:${config.services.phpfpm.pools."${name}-pcov".socket};"
                      "pcov:spx:${name} unix:${config.services.phpfpm.pools."${name}-pcov".socket};"
                      "spx:default:${name} unix:${config.services.phpfpm.pools."${name}-spx".socket};"
                      "spx:spx:${name} unix:${config.services.phpfpm.pools."${name}-spx".socket};"
                    ]
                    else []
                )
                cfg.instances
              )
            )}
            }

            map $cookie_backend $sentry_sample_rate {
                default "";
                excimer "1.0";
            }
          '';
        }
        {
          virtualHosts = mkMerge (
            flatten (
              mapAttrsToList (
                name: opts:
                  if opts.enable
                  then [
                    {
                      "${head opts.domains}" =
                        opts.virtualHost
                        // {
                          serverName = head opts.domains;
                          serverAliases = drop 1 opts.domains;
                          root = opts.publicDir;
                          extraConfig = mkDefault ''
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
                            "/".extraConfig = mkDefault ''
                              try_files $uri /index.php?$query_string;
                            '';

                            "/coverage/".extraConfig = mkDefault ''
                              alias ${opts.dataDir}/pcov/html/;
                              try_files $uri /index.html;
                            '';

                            "~ \\.php$".extraConfig = mkDefault ''
                              set $instance "${name}";
                              include ${nginx.package}/conf/fastcgi.conf;
                              include ${nginx.package}/conf/fastcgi_params;

                              fastcgi_buffering off;
                              fastcgi_index index.php;
                              fastcgi_split_path_info ^(.+\.php)(/.+)$;
                              fastcgi_param SERVER_NAME $http_host;
                              fastcgi_param SCRIPT_FILENAME $request_filename;
                              fastcgi_param PATH_INFO $fastcgi_path_info;

                              # pcov shenanigans
                              fastcgi_param NIX_CHIPS_DIR_DATA ${opts.dataDir};

                              # Per-request configuration
                              fastcgi_param INSTANCE ${name};
                              fastcgi_param FASTCGI_BACKEND $fastcgi_backend;
                              fastcgi_param LOG_LEVEL $log_level;
                              fastcgi_param LOG_STACK_TRACE_ENABLED $log_stack_trace_enabled;
                              fastcgi_param SENTRY_TRACES_SAMPLE_RATE $sentry_sample_rate;
                              fastcgi_param SENTRY_PROFILES_SAMPLE_RATE $sentry_sample_rate;

                              fastcgi_pass $fastcgi_backend;
                            '';
                          };
                        }
                        // (optionalAttrs config.programs.lego.enable {
                          onlySSL = true;
                          sslCertificate = config.programs.lego.certFile;
                          sslCertificateKey = config.programs.lego.keyFile;
                        });
                    }
                  ]
                  else []
              )
              cfg.instances
            )
          );
        }
      ];
    }
    {
      services.traefik = {
        routers = mkMerge (
          flatten (
            mapAttrsToList (
              name: opts:
                if opts.enable
                then [
                  {
                    "${name}" = {
                      service = "nginx";
                      priority = 1;
                      rule = hostRegexp opts.domains;
                    };
                  }
                ]
                else []
            )
            cfg.instances
          )
        );
        services = {
          nginx = {
            loadBalancer.servers = [
              {url = "http://${config.project.address}:${toString config.services.nginx.defaultHTTPListenPort}";}
            ];
          };
        };
      };
    }
    {
      users.users.${cfg.user} = {
        group = cfg.group;
        isSystemUser = true;
      };

      systemd.tmpfiles.rules = flatten (
        mapAttrsToList (
          name: opts:
            if opts.enable
            then [
              "d ${opts.runDir}                             0775 ${cfg.user} ${cfg.group} - -"
              "d ${opts.dataDir}                            0710 ${cfg.user} ${cfg.group} - -"
              "d ${opts.dataDir}/cache                      0750 ${cfg.user} ${cfg.group} - -"
              "d ${opts.dataDir}/spx                        0750 ${cfg.user} ${cfg.group} - -"
              "d ${opts.dataDir}/pcov/html                  0750 ${cfg.user} ${cfg.group} - -"
            ]
            else []
        )
        cfg.instances
      );
    }
    {
      devShell = {
        contents = flatten (
          mapAttrsToList (
            name: opts:
              if opts.enable
              then let
                mkPcovScripts =
                  if config.services.phpfpm.pools ? "${name}-pcov"
                  then [
                    (writeBashBin "php-pcov-${name}" ''
                      exec ${config.services.phpfpm.pools."${name}-pcov".phpPackage}/bin/php $*
                    '')
                    (writeBashBin "pcov-report-${name}" ''
                      cd ${config.dir.project}
                      exec ${
                        config.services.phpfpm.pools."${name}-pcov".phpPackage
                      }/bin/php -d pcov.enabled=1 vendor/bin/phpunit --coverage-html ${opts.dataDir}/pcov/html "$@"
                    '')
                  ]
                  else [];

                mkExcimerScripts =
                  if config.services.phpfpm.pools ? "${name}-excimer"
                  then let
                    php-eximer-entry = writeText "php-eximer-entry-${name}.php" ''
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
                  in [
                    (writeBashBin "php-excimer-${name}" ''
                      exec ${
                        config.services.phpfpm.pools."${name}-excimer".phpPackage
                      }/bin/php -d auto_prepend_file=${php-eximer-entry} $*
                    '')
                  ]
                  else [];
              in
                mkPcovScripts ++ mkExcimerScripts
              else []
          )
          cfg.instances
        );
      };
    }
  ]);
}
