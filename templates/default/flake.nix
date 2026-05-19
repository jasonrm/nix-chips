{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # various, usually obscure, programs that are missing from nixpkgs
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    chips = {
      url = "github:jasonrm/nix-chips";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-staging.follows = "nixpkgs-staging";
    };

    # rust-overlay = {
    #   url = "github:oxalica/rust-overlay";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.flake-utils.follows = "flake-utils";
    # };
  };

  outputs = inputs @ {
    chips,
    # rust-overlay,
    ...
  }:
    chips.lib.mkFlake {inherit inputs;} {
      # Generate new devShells with `nix run .#init-dev-shell <GITHUB_USERNAME>`
      sources.devShells = ./nix/devShells;
      # sources.packages = ./nix/packages;
      # sources.nixosModules = ./nix/nixosModules;
      # sources.dockerImages = ./nix/dockerImages;
      nixpkgs.overlays = [
        # rust-overlay.overlays.default
      ];
    };
}
