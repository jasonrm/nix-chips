{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
    nixpkgs-staging.inputs.nixpkgs.follows = "nixpkgs";

    # chips.follows = "/" breaks the arcanum ↔ chips cycle (arcanum depends on chips).
    arcanum.url = "github:bitnixdev/arcanum";
    arcanum.inputs.nixpkgs.follows = "nixpkgs";
    arcanum.inputs.nixpkgs-staging.follows = "nixpkgs-staging";
    arcanum.inputs.chips.follows = "/";
  };

  outputs = inputs: let
    lib = import ./lib inputs;
  in
    lib.mkFlake {
      inherit inputs;
      sources.devShells = ./devShells;
      nixpkgs.overlays = [lib.overlays.unstable];
      outputs = {
        inherit lib;
        templates.default = {
          path = ./templates/default;
          description = "nix flake new -t github:jasonrm/nix-chips .";
        };
      };
      perSystem = {
        pkgs,
        self,
        ...
      }: {
        formatter = pkgs.alejandra;
        packages.docs-data = pkgs.callPackage ./docs/generate-options.nix {
          inherit self;
        };
      };
    };
}
