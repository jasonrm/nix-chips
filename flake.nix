{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    utils.url = "github:numtide/flake-utils";

    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
    nixpkgs-staging.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-staging.inputs.utils.follows = "utils";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-staging,
    home-manager,
    utils,
    ...
  } @ inputs:
    {
      lib = import ./lib inputs;
    }
    // {
      templates.default = {
        path = ./templates/default;
        description = "nix flake new -t github:jasonrm/nix-chips .";
      };
    };
}
