{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.elasticmq;
in
{
  options = {
    services.elasticmq = with lib.types; {
      enable = lib.mkEnableOption "Enable elasticmq.";
      configFile = lib.mkOption {
        type = nullOr path;
        default = null;
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      devShell.environment = [ "ELASTICMQ_BASE_URL=http://127.0.0.1:9324/queue/" ];

      programs.supervisord.programs = {
        elasticmq = {
          command = "${pkgs.elasticmq-server-bin}/bin/elasticmq-server";
          environment =
            if cfg.configFile != null then [ "JAVA_TOOL_OPTIONS=-Dconfig.file=${cfg.configFile}" ] else [ ];
        };
      };
    })
  ];
}
