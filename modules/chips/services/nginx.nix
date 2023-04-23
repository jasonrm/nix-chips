{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption;

  cfg = config.services.nginx;

  execCommand = pkgs.writeShellScriptBin "nginx" ''
    ${config.systemd.services.nginx.preStart}
    exec ${config.systemd.services.nginx.serviceConfig.ExecStart}
  '';
in {
  imports = [
  ];

  config = lib.mkIf cfg.enable {
    programs.supervisord.programs.nginx = {
      command = "${execCommand}/bin/nginx";
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
