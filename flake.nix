{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
    nixpkgs-staging.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    lib = import ./lib inputs;
  in
    lib.mkFlake {
      inherit inputs;
      sources.devShells = ./devShells;
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
