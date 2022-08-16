{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-staging, utils }:
    let
      inherit (nixpkgs.lib) evalModules hasSuffix;
      inherit (nixpkgs.lib.filesystem) listFilesRecursive;
      inherit (utils.lib) eachDefaultSystem;

      onlyNix = baseName: (hasSuffix ".nix" baseName);

      localModules = directory: builtins.filter onlyNix (listFilesRecursive directory);
      nixChipModules = localModules ./modules;

      evalNixChip = modules: args: (eachDefaultSystem (system:
        (evalModules {
          specialArgs = (args.specialArgs or { }) // {
            overlays = (args.overlay or [ ]) ++ [ nixpkgs-staging.overlay ];
            inherit nixpkgs;
            inherit system;
            chips = import ./lib { lib = nixpkgs.lib; };
          };
          modules = (args.nixosModules or [ ]) ++ [{ imports = nixChipModules ++ modules; }];
        }).config.outputs));

    in
    (evalNixChip [ ] { }) // {
      use = dir: args: evalNixChip (localModules dir) args;
      nixosModule = { imports = nixChipModules; };
    };
}
