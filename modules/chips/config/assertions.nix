{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    assertions = mkOption {
      type = str;
    };
  };
}
