{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    security = mkOption {
      type = attrs;
    };
  };
}
