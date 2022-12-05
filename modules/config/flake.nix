{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption;

  cfg = config.flake;

  appOption = with lib.types; {name, ...}: let
    appOption = outputs.apps.${name};
  in {
    options = {
      type = mkOption {
        type = str;
        default = "app";
      };
      program = mkOption {
        type = oneOf [path str];
      };
    };
  };
in {
  imports = [
  ];

  options = with lib.types; {
    outputs = {
      apps = mkOption {
        default = {};
        type = attrsOf (submodule appOption);
      };
      devShell = mkOption {
        default = null;
        type = nullOr package;
      };
      packages = mkOption {
        default = {};
        type = attrsOf package;
      };
      defaultPackage = mkOption {
        default = null;
        type = nullOr package;
      };
    };
  };

  config = {};
}
