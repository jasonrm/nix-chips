{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    systemd.services.mysql = mkOption {
      type = attrs;
    };
  };
}
