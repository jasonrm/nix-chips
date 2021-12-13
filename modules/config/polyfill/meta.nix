{ lib, pkgs, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  options = with types; {
    meta = mkOption {
      default = {};
      type = attrsOf attrSet;
    };
  };
}
