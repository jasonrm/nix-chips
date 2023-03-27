{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-staging,
    utils,
  }: let
    inherit (nixpkgs.lib) evalModules hasSuffix;
    inherit (nixpkgs.lib.filesystem) listFilesRecursive;
    inherit (utils.lib) eachDefaultSystem;

    onlyNix = baseName: (hasSuffix ".nix" baseName);

    localModules = directory: builtins.filter onlyNix (listFilesRecursive directory);
    nixChipModules = localModules ./modules/chips;
    nixosModules = localModules ./modules/nixos;
    sharedModules = localModules ./modules/shared;

    evalNixChip = modules: args: (eachDefaultSystem (system:
      (evalModules {
        specialArgs =
          (args.specialArgs or {})
          // {
            overlays = (args.overlay or []) ++ [nixpkgs-staging.overlay];
            inherit nixpkgs;
            inherit system;
            chips = import ./lib {
              pkgs = nixpkgs.legacyPackages.${system};
              lib = nixpkgs.lib;
            };
          };
        modules = (args.nixosModules or []) ++ [{imports = sharedModules ++ nixChipModules ++ modules;}];
      })
      .config
      .outputs));

    moduleOutputs = evalNixChip [] {};
  in
    moduleOutputs
    // {
      use = modulesDir: args: evalNixChip (localModules modulesDir) args;
      useProfile = modulesDir: profile: evalNixChip (localModules modulesDir) {nixosModules = [profile];};
      lib = import ./lib {
        pkgs = nixpkgs;
        lib = nixpkgs.lib;
      };
      nixosModules.default = {imports = nixosModules ++ sharedModules;};
      # FIXME: This is a hack to get the secretRecipients output from the nixosModules
      secretRecipients = moduleOutputs.secretRecipients."aarch64-darwin";
    };
}
