{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption;

  cfg = config.services.nginx;

  nginxConfig = pkgs.writeText "nginx.conf" ''
    user nobody nobody;
    daemon off;
    worker_processes ${toString cfg.workerProcesses};

    error_log "${cfg.errorLog}";
    pid "${cfg.runDir}/nginx.pid";

    events {
        worker_connections ${toString cfg.workerConnections};
    }

    http {
        map_hash_bucket_size 128;

        access_log "${cfg.accessLog}";

        map $http_upgrade $connection_upgrade {
            default upgrade;
            ""      close;
        }

        client_body_temp_path "${cfg.runDir}/client-body" 1 2;
        proxy_temp_path "${cfg.runDir}/nginx-proxy";
        fastcgi_temp_path "${cfg.runDir}/nginx-fastcgi";
        uwsgi_temp_path "${cfg.runDir}/nginx-uwsgi";
        scgi_temp_path "${cfg.runDir}/nginx-scgi";

        include            ${cfg.package}/conf/mime.types;
        default_type       application/octet-stream;
        sendfile           on;
        tcp_nopush         on;
        keepalive_timeout  65;
        index              index.html index.htm;

        chunked_transfer_encoding off;

        types_hash_max_size 2048;
        types_hash_bucket_size 128;

        # Private IPs
        set_real_ip_from 127.0.0.1;
        set_real_ip_from 10.0.0.0/8;
        set_real_ip_from 172.16.0.0/12;
        set_real_ip_from 192.168.0.0/16;

        real_ip_header X-Forwarded-For;
        real_ip_recursive on;

        fastcgi_keep_conn on;
        fastcgi_index index.php;
        fastcgi_intercept_errors off;
        fastcgi_ignore_client_abort off;
        fastcgi_connect_timeout 5;
        fastcgi_send_timeout 180;
        fastcgi_read_timeout 180;
        fastcgi_buffers 16 4k;
        fastcgi_buffer_size 32k;
        fastcgi_busy_buffers_size 32k;

        gzip on;
        gzip_proxied any;
        gzip_comp_level 5;
        gzip_types
          application/atom+xml
          application/javascript
          application/json
          application/xml
          application/xml+rss
          image/svg+xml
          text/css
          text/javascript
          text/plain
          text/xml;
        gzip_vary on;

        ${cfg.extraConfig}

        ${lib.concatStringsSep "\n" cfg.servers}
    }
  '';

  dockerConfig = pkgs.writeText "nginx.conf" ''
    user nobody nobody;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;
    events {}
    http {
      access_log /dev/stdout;
      ${cfg.extraConfig}
      ${lib.concatStringsSep "\n" cfg.servers}
    }
  '';
  dockerDefaultServer = ''
    server {
      listen 8080;
      index index.html;
      location / {
        root ${nginxWebRoot};
      }
    }
  '';
  nginxWebRoot = pkgs.writeTextDir "index.html" ''
    <html><body><h1>Hello from NGINX</h1></body></html>
  '';
in {
  imports = [
  ];

  options = with lib.types; {
    services.nginx = {
      enable = lib.mkEnableOption "enable nginx";
      package = mkOption {
        default = pkgs.nginxMainline;
        type = types.package;
        apply = p:
          p.override {
            modules = p.modules ++ cfg.additionalModules;
          };
      };
      workerProcesses = mkOption {
        type = int;
        default = 4;
      };
      workerConnections = mkOption {
        type = int;
        default = 1024;
      };
      accessLog = mkOption {
        type = str;
        default = "${cfg.logDir}/access.log";
      };
      errorLog = mkOption {
        type = str;
        default = "${cfg.logDir}/error.log";
      };
      additionalModules = mkOption {
        default = [];
        type = listOf (attrsOf anything);
      };
      # user = mkOption {
      #   type = nullOr str;
      #   default = config.default.user;
      # };
      # group = mkOption {
      #   type =  nullOr str;
      #   default = config.default.group;
      # };
      runDir = mkOption {
        type = str;
        default = "${config.dir.run}/nginx";
      };
      logDir = mkOption {
        type = str;
        default = "${config.dir.log}/nginx";
      };
      servers = mkOption {
        type = listOf str;
        default = [defaultServerDocker];
      };
      extraConfig = mkOption {
        type = str;
        default = "";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dir.ensureExists = [
      cfg.runDir
      cfg.logDir
    ];
    services.promtail.scrapeConfigs = [
      {
        job_name = "nginx";
        static_configs = [
          {
            labels = {
              service = "nginx";
              job = "access";
              "__path__" = "${cfg.logDir}/access.log";
            };
          }
          {
            labels = {
              service = "nginx";
              job = "error";
              "__path__" = "${cfg.logDir}/error.log";
            };
          }
        ];
      }
    ];
    programs.supervisord.programs.nginx = {
      # user = cfg.user;
      # group = cfg.group;
      command = "${cfg.package}/bin/nginx -c ${nginxConfig}";
    };
    dockerImages.images.nginx = {
      contents = with pkgs; [
        pkgs.dockerTools.fakeNss
      ];

      extraCommands = ''
        # nginx still tries to read this directory even if error_log
        # directive is specifying another file :/
        mkdir -p var/log/nginx
        mkdir -p var/cache/nginx
      '';

      config = {
        Cmd = ["${cfg.package}/bin/nginx" "-T" "-c" dockerConfig];
      };
    };
  };
}
