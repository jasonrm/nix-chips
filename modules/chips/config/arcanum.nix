{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.arcanum;
  secretEnvFiles = filterAttrs (n: secret: secret.dest != null && secret.isEnvFile == true) cfg.files;
in
{
  config = mkIf cfg.enable {
    devShell.contents = [ pkgs.arcanum ];

    devShell.envFiles = mapAttrsToList (name: secret: "${secret.dest}") secretEnvFiles;
  };
}
