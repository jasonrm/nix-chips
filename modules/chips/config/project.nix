{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.project;
in {
  imports = [];

  options = with types; {
    project = {
      name = mkOption {type = str;};
      domainSuffix = mkOption {
        type = str;
        default = "bitnix.dev";
      };
      address = mkOption {
        type = str;
        default = "127.0.0.1";
        description = "Loopback address for this project. Must be in 127.0.0.0/8. Use a unique address per project to avoid port conflicts.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.hasPrefix "127." cfg.address;
        message = "project.address must be in the 127.0.0.0/8 range, got: ${cfg.address}";
      }
    ];

    devShell = {
      environment = [
        "DOMAIN_SUFFIX=${cfg.domainSuffix}"
        "NIX_CHIPS_ADDRESS=${cfg.address}"
      ];
    };
  };
}
