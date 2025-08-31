{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption;

  cfg = config.services.minio;
in {
  imports = [];

  config = lib.mkIf cfg.enable {
    devShell = {
      contents = [pkgs.minio];
    };
  };
}
