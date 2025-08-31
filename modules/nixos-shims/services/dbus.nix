{
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; {
  options = with types; {
    services.dbus = mkOption {type = attrs;};
  };
}
