{ lib, pkgs, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  options = with types; {
    networking = mkOption {
      default = {};
      type = attrsOf attrSet;
    };
  };
}
