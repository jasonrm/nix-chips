{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    utils.url = "github:numtide/flake-utils";

    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
    nixpkgs-staging.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {self, ...}: let
    lib = import ./lib inputs;
    output = lib.mkFlake {inherit inputs;} {
      sources.devShells = ./devShells;
      nixpkgs.overlays = [lib.overlays.unstable];
      perSystem = {pkgs, ...}: {
        packages.docs-data = pkgs.callPackage ./docs/generate-options.nix {
          inherit self;
        };
      };
    };
  in
    output
    // {
      inherit lib;
    }
    // {
      templates.default = {
        path = ./templates/default;
        description = "nix flake new -t github:jasonrm/nix-chips .";
      };
    };
}
