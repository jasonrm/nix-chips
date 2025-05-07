{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption;

  appOption =
    with lib.types;
    { name, ... }:
    let
      appOption = outputs.apps.${name};
    in
    {
      options = {
        type = mkOption {
          type = str;
          default = "app";
        };
        program = mkOption {
          type = oneOf [
            path
            str
          ];
        };
      };
    };
in
{ }
