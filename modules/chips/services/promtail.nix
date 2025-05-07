{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.promtail;

  promtailConfig = pkgs.writeText "promtail-local-config.yaml" (
    builtins.toJSON {
      server = {
        http_listen_port = cfg.portHttp;
        grpc_listen_port = 0;
      };
      positions = {
        filename = "${cfg.logDir}/positions.yaml";
      };
      clients = [ { url = ''''${LOKI_URI}''; } ];
      scrape_configs = cfg.scrapeConfigs;
    }
  );

  scrapeConfig = {
    options = {
      job_name = lib.mkOption { type = lib.types.str; };
      static_configs = lib.mkOption {
        type = with lib.types; listOf attrs;
        default = [ ];
      };
      pipeline_stages = lib.mkOption {
        type = with lib.types; listOf attrs;
        default = [ ];
      };
    };
  };
in
{
  imports = [ ];

  options = {
    services.promtail = {
      enable = lib.mkEnableOption "enable promtail";
      scrapeConfigs = lib.mkOption {
        default = [ ];
        type = with lib.types; listOf (submodule scrapeConfig);
      };

      # user = lib.mkOption {
      #   type = with lib.types; nullOr str;
      #   default = config.default.user;
      # };
      # group = lib.mkOption {
      #   type = with lib.types; nullOr str;
      #   default = config.default.group;
      # };

      logDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.dir.log}/promtail";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      portHttp = lib.mkOption {
        type = lib.types.int;
        default = 0;
      };

      lokiHost = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      lokiPortHttp = lib.mkOption {
        type = lib.types.int;
        default = 3100;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # docker.preCommand = [
    #   "mkdir -p ${lib.escapeShellArg cfg.logDir}"
    #   "chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg cfg.logDir}"
    # ];
    # docker.environment = [
    #   "LOKI_URI=http://${cfg.lokiHost}:${toString cfg.lokiPortHttp}/loki/api/v1/push"
    # ];
    programs.supervisord.programs.promtail = {
      # user = cfg.user;
      # group = cfg.group;
      command = "${pkgs.grafana-loki}/bin/promtail --config.expand-env=true --config.file=${promtailConfig}";
    };
  };
}
