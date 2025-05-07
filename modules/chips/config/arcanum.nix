{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.arcanum;
in
{
  config = mkIf cfg.enable { devShell.contents = [ pkgs.arcanum ]; };
}
