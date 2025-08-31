{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    networking = {
      enableIPv6 = mkOption {
        type = bool;
        default = true;
      };
      firewall = mkOption {type = attrs;};
    };
  };
}
