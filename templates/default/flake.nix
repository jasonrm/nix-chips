{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    chips = {
      url = "github:jasonrm/nix-chips";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-staging.follows = "nixpkgs-staging";
    };

    # flake-utils = {
    #   url = "github:numtide/flake-utils";
    # };

    # rust-overlay = {
    #   url = "github:oxalica/rust-overlay";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.flake-utils.follows = "flake-utils";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      chips,
      # rust-overlay,
      ...
    }:
    chips.lib.use {
      devShellsDir = ./nix/devShells;
      # packagesDir = ./nix/packages;
      # nixosModulesDir = ./nix/nixosModules;
      # dockerImagesDir = ./nix/dockerImages;
      overlays = [
        # rust-overlay.overlays.default
      ];
    };
}
