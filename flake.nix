{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    utils.url = "github:numtide/flake-utils";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
  };

  outputs = { self, nixpkgs, utils, nixpkgs-staging }:
    let
      inherit (nixpkgs.lib) evalModules hasSuffix;
      inherit (nixpkgs.lib.filesystem) listFilesRecursive;
      inherit (utils.lib) eachDefaultSystem;

      onlyNix = baseName: (hasSuffix ".nix" baseName);

      localModules = directory: builtins.filter onlyNix (listFilesRecursive directory);
      nixChipModules = localModules ./modules;

      evalNixChip = modules: (eachDefaultSystem (system: (evalModules {
        specialArgs = { inherit nixpkgs system nixpkgs-staging; };
        modules = [{ imports = nixChipModules ++ modules; }];
      }).config.outputs));

    in
    (evalNixChip []) // {
      use = dir: evalNixChip (localModules dir);
      nixosModule = { imports = nixChipModules; };
    };
}
