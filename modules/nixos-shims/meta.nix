{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    meta = {
      maintainers = mkOption {
        type = listOf string;
      };
    };
  };
}
