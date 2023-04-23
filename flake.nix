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
  }:
    with nixpkgs.lib; let
      inherit (nixpkgs.lib.filesystem) listFilesRecursive;
      inherit (utils.lib) eachSystem eachDefaultSystem;

      onlyNix = baseName: (hasSuffix ".nix" baseName);

      localModules = directory: builtins.filter onlyNix (listFilesRecursive directory);
      nixChipModules = localModules ./modules/chips;
      nixosModules = localModules ./modules/nixos;
      sharedModules = localModules ./modules/shared;

      evalNixChip = modules: args: (eachDefaultSystem (system:
        (evalModules {
          specialArgs =
            (args.specialArgs or {})
            // rec {
              overlays = (args.overlays or []) ++ [nixpkgs-staging.overlay];
              pkgs = import nixpkgs {
                inherit overlays;
                inherit system;
              };
              modulesPath = pkgs.path + "/nixos/modules";
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

      useChecks = {
        checks,
        overlays,
        self,
      }: let
        makeCheck = system: name: check:
          (import ./lib/makeCheck.nix) (import check) {
            pkgs = import nixpkgs {
              inherit overlays;
              inherit system;
            };
            inherit self;
          };
      in
        (eachSystem [utils.lib.system.x86_64-linux]) (system: {
          checks = mapAttrs (makeCheck system) checks;
        });

      moduleOutputs = evalNixChip [] {};
    in
      moduleOutputs
      // {
        inherit useChecks;
        use = modulesDir: args: evalNixChip (localModules modulesDir) args;
        useProfile = modulesDir: profile: evalNixChip (localModules modulesDir) {nixosModules = [profile];};
        lib = import ./lib {
          pkgs = nixpkgs;
          lib = nixpkgs.lib;
        };
        nixosModules.default = {imports = nixosModules ++ sharedModules;};
        # FIXME: This is a hack to get the secretRecipients output from the nixosModules
        secretRecipients = moduleOutputs.secretRecipients.aarch64-darwin;
      };
}
