{ lib, pkgs, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  options = with types; {
    environment.systemPackages = mkOption {
      default = {};
      type = listOf pkg;
    };
  };
}
