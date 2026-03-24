{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    meta = {
      maintainers = mkOption {type = listOf str;};
      teams = mkOption {
        type = listOf raw;
        default = [];
      };
    };
  };
}
