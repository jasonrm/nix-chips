{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    systemd.services.phpfpm = {
      pools = mkOption {
        type = attrsOf (submodule {
          options = {
            phpEnv = mkOption {
              type = listOf str;
            };
          };
        });
      };
    };
  };
}
