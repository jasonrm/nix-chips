{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    chips.url = "github:jasonrm/nix-chips";
    chips.inputs.nixpkgs.follows = "nixpkgs";
    chips.inputs.nixpkgs-staging.follows = "nixpkgs-staging";
  };

  outputs = {
    self,
    nixpkgs,
    chips,
    ...
  }:
    chips.lib.use {
      devShellsDir = ./nix/devShells;
      # packagesDir = ./nix/packages;
      # nixosModulesDir = ./nix/nixosModules;
      # dockerImagesDir = ./nix/dockerImages;
    };
}
