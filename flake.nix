{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    utils.url = "github:numtide/flake-utils";

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
