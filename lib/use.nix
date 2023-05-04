{
  self,
  nixpkgs,
  nixpkgs-staging,
  utils,
  ...
}:
with nixpkgs.lib; let
  inherit (filesystem) listFilesRecursive;
  inherit (utils.lib) eachSystem eachDefaultSystem;

  chipsLib = import ./arcanum.nix {lib = nixpkgs.lib;};

  onlyNix = baseName: (hasSuffix ".nix" baseName);
  nixFilesIn = directory: builtins.filter onlyNix (listFilesRecursive directory);

  nixChipModules = nixFilesIn ../modules/chips;
  nixosChipModules = nixFilesIn ../modules/nixos;
  nixosShimModules = nixFilesIn ../modules/nixos-shims;
  sharedChipModules = nixFilesIn ../modules/shared;

  chipPackages = nixFilesIn ../packages;
  chipApps = nixFilesIn ../apps;

  useApps = {
    appsDir,
    overlay,
  }: let
    allApps =
      chipApps
      ++ (
        if appsDir != null
        then nixFilesIn appsDir
        else []
      );
  in
    with utils.lib;
      (eachDefaultSystem (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [overlay];
          };
        in {
          apps = listToAttrs (map (name: {
              name = removeSuffix ".nix" (baseNameOf name);
              value = pkgs.callPackage name {};
            })
            allApps);
        }
      ))
      .apps;

  mkPackagesOverlay = packagesDir: final: prev: let
    packages =
      (
        if packagesDir != null
        then nixFilesIn packagesDir
        else []
      )
      ++ chipPackages;
  in
    listToAttrs (map (name: {
        name = removeSuffix ".nix" (baseNameOf name);
        value = prev.callPackage name {};
      })
      packages);

  evalChipsModules = {
    pkgs,
    system,
    modules ? [],
  }:
    (evalModules {
      inherit modules;
      specialArgs = {
        inherit pkgs system;
        chips = self;
        modulesPath = pkgs.path + "/nixos/modules";
      };
    })
    .config
    .outputs;

  useDevShells = {
    devShellsDir,
    modules,
    overlay,
  }:
    with utils.lib;
      (eachDefaultSystem (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [overlay];
          };
        in {
          devShells = listToAttrs (map (name: {
            name = removeSuffix ".nix" (baseNameOf name);
            value =
              (evalChipsModules {
                inherit pkgs system;
                modules = modules ++ [name];
              })
              .devShell;
          }) (nixFilesIn devShellsDir));
        }
      ))
      .devShells;

  usePackages = {
    packagesDir,
    overlay,
  }: let
    allPackages = (nixFilesIn packagesDir) ++ chipPackages;
  in
    with utils.lib;
      (eachDefaultSystem (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [overlay];
          };
        in {
          packages = listToAttrs (map (name: {
              name = removeSuffix ".nix" (baseNameOf name);
              value = pkgs.callPackage name {};
            })
            allPackages);
        }
      ))
      .packages;

  useChecks = {
    self,
    checksDir,
    modules,
    overlay,
  }: let
    checks = nixFilesIn checksDir;
    makeCheck = system: check:
      (import ./makeCheck.nix) (import check) {
        self = {
          nixosModules.default = modules;
          overlays.default = overlay;
        };
        pkgs = import nixpkgs {
          inherit system;
          overlays = [overlay];
        };
      };
  in
    ((eachSystem [utils.lib.system.x86_64-linux]) (system: {
      checks = listToAttrs (map (check: {
          name = removeSuffix ".nix" (baseNameOf check);
          value = makeCheck system check;
        })
        checks);
    }))
    .checks;

  mkManual = {modules}: let
  in
    (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({...}: {
          config = {
            documentation.nixos.extraModules = map toString modules;
          };
        })
      ];
    })
    .config
    .system
    .build
    .manual;

  useNixosConfigurations = {
    nixosConfigurationsDir,
    modules,
    overlay,
  }: let
    onlyDefaultNix = baseName: (hasSuffix "default.nix" baseName);

    configurations = map (n: {
      name = builtins.baseNameOf (builtins.dirOf n);
      path = n;
    }) (builtins.filter onlyDefaultNix (nixFilesIn nixosConfigurationsDir));

    nixosConfigurations = builtins.listToAttrs (map (
        configuration:
          nameValuePair configuration.name (
            nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = {
                nodes = nixosConfigurations;
              };
              modules =
                [
                  ({...}: {
                    config = {
                      nixpkgs.overlays = [overlay];
                    };
                  })
                ]
                ++ modules
                ++ [configuration.path];
            }
          )
      )
      configurations);
  in
    nixosConfigurations;
in
  {
    appsDir ? null,
    checksDir ? null,
    devShellsDir ? null,
    packagesDir ? null,
    nixosModulesDir ? null,
    nixosConfigurationsDir ? null,
    nixosModules ? [],
    overlays ? [],
    arcanum ? {},
    ...
  }: let
    projectNixosModules =
      if nixosModulesDir != null
      then nixFilesIn nixosModulesDir
      else [];

    mergedNixChipModules =
      nixChipModules
      ++ nixosShimModules
      ++ sharedChipModules
      ++ projectNixosModules;

    mergedNixosModules =
      nixosChipModules
      ++ nixosModules
      ++ sharedChipModules
      ++ projectNixosModules;

    overlay = self.lib.mergeOverlays (overlays ++ [(mkPackagesOverlay packagesDir) nixpkgs-staging.overlays.default]);

    packages = optionalAttrs (packagesDir != null) (usePackages {inherit overlay packagesDir;});

    devShells = optionalAttrs (devShellsDir != null) (useDevShells {
      inherit devShellsDir overlay;
      modules =
        nixChipModules
        ++ nixosShimModules
        ++ sharedChipModules;
    });

    checks = optionalAttrs (checksDir != null) (useChecks {
      inherit self checksDir overlay;
      modules = mergedNixosModules;
    });

    apps = optionalAttrs (appsDir != null) (useApps {inherit appsDir overlay;});

    nixosConfigurations = optionalAttrs (nixosConfigurationsDir != null) (useNixosConfigurations {
      inherit nixosConfigurationsDir overlay;
      modules = mergedNixosModules;
    });
  in {
    inherit devShells packages checks apps nixosConfigurations;
    nixosModules.default = nixosModules ++ projectNixosModules;
    overlays.default = overlay;
    lib = {
      manual = mkManual {modules = mergedNixosModules;};
      arcanum = (chipsLib.recipientsFromConfigurations nixosConfigurations) // (mapAttrs' (name: file: nameValuePair file.source ((file.recipients or []) ++ arcanum.adminRecipients)) (arcanum.files or {}));
    };
  }
