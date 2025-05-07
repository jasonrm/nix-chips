{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption;

  cfg = config.services.nginx;

  customConfigPath = pkgs.runCommand "nginx.conf" { } ''
    CONFIG_FILE=$(echo "${config.systemd.services.nginx.serviceConfig.ExecStart}" | sed "s/.*-c '\([^']*\)'.*/\1/g")
    cp $CONFIG_FILE $out
    substituteInPlace $out --replace "/run/nginx/" "${config.dir.data}/nginx/"
  '';

  execCommand = pkgs.writeShellScriptBin "nginx" ''
    ${cfg.preStart}
    ${cfg.package}/bin/nginx -c '${customConfigPath}' -t
    exec ${cfg.package}/bin/nginx -c '${customConfigPath}'
  '';

  nginx-debug = pkgs.writeShellScriptBin "nginx-debug" ''
    cat ${customConfigPath}
  '';
in
{
  imports = [ ];

  config = lib.mkIf cfg.enable {
    services.nginx = {
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      appendHttpConfig = ''
        access_log  ${config.dir.data}/nginx/access.log;
        error_log  ${config.dir.data}/nginx/error.log;

        # Override all the temp directories to make nginx happy
        client_body_temp_path ${config.dir.data}/nginx/client_body_temp;
        proxy_temp_path ${config.dir.data}/nginx/proxy_temp;
        fastcgi_temp_path ${config.dir.data}/nginx/fastcgi_temp;
        uwsgi_temp_path ${config.dir.data}/nginx/uwsgi_temp;
        scgi_temp_path ${config.dir.data}/nginx/scgi_temp;
      '';
    };
    programs.supervisord.programs.nginx = {
      command = "${execCommand}/bin/nginx";
    };
    devShell = {
      contents = [ nginx-debug ];
    };
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
  };
}
