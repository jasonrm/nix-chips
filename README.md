
## Example Use

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";

    chips.url = "github:jasonrm/nix-chips";
    chips.inputs.nixpkgs.follows = "nixpkgs";
    chips.inputs.utils.follows = "utils";
  };

  outputs = { self, nixpkgs, utils, chips, ... }:
    let
      inherit (nixpkgs.lib) evalModules;
      inherit (utils.lib) eachDefaultSystem;

      projectModule = { system, pkgs, lib, config, ... }: {
        config = {
          nodejs = {
            enable = true;
            pkg = pkgs.nodejs-14_x;
          };
          php = {
            enable = true;
            extensions = { enabled, all, ... }: with all; enabled ++ [
              pcov
            ];
          };
        };
      };
    in
    (eachDefaultSystem (system: (evalModules {
      specialArgs = { inherit nixpkgs system; };
      modules = [ chips.nixosModule projectModule ];
    }).config.outputs));
}
```