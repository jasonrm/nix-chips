{ lib, pkgs, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.project;
in
{
  imports = [
  ];

  options = with types; {
    project = {
      name = mkOption {
        type = str;
      };
    };
  };

  config = { };
}
