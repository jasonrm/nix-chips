{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    systemd.tmpfiles = mkOption {
      type = attrs;
    };
  };
}
