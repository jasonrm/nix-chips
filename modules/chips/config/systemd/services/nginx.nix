{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    systemd.services.nginx = mkOption {
      type = submodule {
        options = {
          enable = mkOption {
            type = bool;
          };
          group = mkOption {
            type = str;
          };
        };
      };
    };
  };
}
