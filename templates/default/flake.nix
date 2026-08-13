{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # various, usually obscure, programs that are missing from nixpkgs
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
    nixpkgs-staging.inputs.nixpkgs.follows = "nixpkgs";

    chips = {
      url = "github:jasonrm/nix-chips";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-staging.follows = "nixpkgs-staging";
    };

    # Optional: add encrypted-secret support from arcanum.
    # arcanum.url = "github:bitnixdev/arcanum";
    # arcanum.inputs.nixpkgs.follows = "nixpkgs";
    # arcanum.inputs.nixpkgs-staging.follows = "nixpkgs-staging";
    # arcanum.inputs.chips.follows = "chips";

    # rust-overlay = {
    #   url = "github:oxalica/rust-overlay";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = inputs @ {
    chips,
    # arcanum,
    # rust-overlay,
    ...
  }:
    chips.lib.mkFlake {
      inherit inputs;
      # Generate new devShells with `nix run .#init-dev-shell <GITHUB_USERNAME>`
      sources.devShells = ./nix/devShells;
      # sources.packages = ./nix/packages;
      # sources.nixosModules = ./nix/nixosModules;
      # sources.dockerImages = ./nix/dockerImages;
      # modules.chips = [arcanum.chipsModules.default];
      nixpkgs.overlays = [
        # arcanum.overlays.default
        # rust-overlay.overlays.default
      ];
    };
}
