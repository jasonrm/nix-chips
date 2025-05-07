{ pkgs, lib, ... }:
with lib;
{
  options = with types; {
    users = mkOption {
      type = attrs;
      default = { };
    };
  };
}
