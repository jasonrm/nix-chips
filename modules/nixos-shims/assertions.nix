{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    assertions = mkOption {
      type = oneOf [str attrs (listOf attrs)];
    };
  };
}
