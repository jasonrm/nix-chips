{ pkgs, lib, ... }:
with lib;
{
  options = with types; {
    environment = mkOption { type = str; };
  };
}
