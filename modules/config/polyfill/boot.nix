{ lib, pkgs, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  options = with types; {
    boot = mkOption {
      default = {};
      type = attrsOf attrSet;
    };
  };
}
