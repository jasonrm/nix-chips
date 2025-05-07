{ pkgs, lib, ... }:
with lib;
{
  options = with types; {
    system = {
      stateVersion = mkOption {
        type = str;
        default = "22.11";
      };
    };
  };
}
