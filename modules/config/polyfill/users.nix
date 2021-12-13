{ lib, pkgs, config, ... }:
let
  inherit (lib) types mkOption;
  cfg = config.dir;
in
{
  imports = [
  ];

  options = with types; {
    users.users = mkOption {
      default = {};
      type = attrsOf attrSet;
    };
    users.groups = mkOption {
      default = {};
      type = attrsOf attrSet;
    };
  };

  config = {
  };
}
