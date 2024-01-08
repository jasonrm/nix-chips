{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.arcanum;
in {
  config = {
    devShell.contents = [
      pkgs.arcanum
    ];
  };
}
