{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    systemd = {
      services = mkOption {
        type = attrs;
      };
      tmpfiles = mkOption {
        type = attrs;
      };
    };
  };
}
