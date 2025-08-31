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
    };
  };

  config = {
    devShell = {
      environment = ["DOMAIN_SUFFIX=${cfg.domainSuffix}"];
    };
  };
}
