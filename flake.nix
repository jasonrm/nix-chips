{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
  };

  outputs = { self, nixpkgs, utils, nixpkgs-staging }:
    let
      inherit (nixpkgs.lib) evalModules;
      inherit (nixpkgs.lib.filesystem) listFilesRecursive;
      inherit (utils.lib) eachDefaultSystem;

      nixosModule = {
        imports = listFilesRecursive ./modules;
      };

      outputs = (eachDefaultSystem (system: (evalModules {
        specialArgs = { inherit nixpkgs system nixpkgs-staging; };
        modules = [ nixosModule ] ++ [
          # ./examples/nginx-php-mysql.nix
        ];
      }).config.outputs));
    in
    outputs // {
      inherit nixosModule;
    };
}
