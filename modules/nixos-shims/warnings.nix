{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    warnings = mkOption {type = str;};
  };
}
