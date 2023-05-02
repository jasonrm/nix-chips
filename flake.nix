{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging/flakes";

    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-staging,
    utils,
    ...
  } @ inputs: {
    lib = import ./lib inputs;
  };
}
