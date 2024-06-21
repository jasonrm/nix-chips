{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.dynamodb;
in {
  options = {
    services.dynamodb = with lib.types; {
      enable = lib.mkEnableOption "enable dynamodb";
      port = lib.mkOption {
        type = int;
        default = config.ports.dynamodb;
      };
      dataDir = lib.mkOption {
        type = path;
        default = "${config.dir.data}/dynamodb";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      dir.ensureExists = [
        cfg.dataDir
      ];
      devShell.environment = [
        "AWS_ENDPOINT_URL_DYNAMODB=http://127.0.0.1:${toString cfg.port}"
      ];

      programs.supervisord.programs = {
        dynamodb = {
          directory = cfg.dataDir;
          command = "${pkgs.dynamodb}/bin/dynamodb-local";
          environment = [
            "DYNAMODB_PORT=${toString cfg.port}"
            "DYNAMODB_DATA_PATH=${cfg.dataDir}"
          ];
        };
      };
    })
  ];
}
