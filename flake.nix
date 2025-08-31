{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
    nixpkgs-staging.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {nixpkgs-unstable, ...} @ inputs: let
    lib = import ./lib inputs;
    output = lib.use {
      devShellsDir = ./devShells;
      overlays = [lib.overlays.default];
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
