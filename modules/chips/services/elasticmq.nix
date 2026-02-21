{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.elasticmq;
  javaToolOptionsList =
    (
      if cfg.configFile != null
      then ["-Dconfig.file=${cfg.configFile}"]
      else []
    )
    ++ (lib.optional cfg.preferIPv4Stack "-Djava.net.preferIPv4Stack=true");
  javaToolOptions = lib.concatStringsSep " " javaToolOptionsList;
in {
  options = {
    services.elasticmq = with lib.types; {
      enable = lib.mkEnableOption "Enable elasticmq.";
      configFile = lib.mkOption {
        type = nullOr path;
        default = null;
      };
      preferIPv4Stack = lib.mkOption {
        type = bool;
        default = true;
        description = "Whether to pass -Djava.net.preferIPv4Stack=true to the JVM.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      devShell.environment = ["ELASTICMQ_BASE_URL=http://${config.project.address}:9324/queue/"];

      programs.supervisord.programs = {
        elasticmq = {
          command = "${pkgs.elasticmq-server-bin}/bin/elasticmq-server";
          environment =
            lib.optional (javaToolOptions != "") "JAVA_TOOL_OPTIONS=${javaToolOptions}";
        };
      };
    })
  ];
}
