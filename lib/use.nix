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
    .config;

  useDevShells = {
    devShellsDir,
    modules,
    overlay,
  }: let
    nixFiles = nixFilesIn devShellsDir;
  in
    with utils.lib;
      (eachDefaultSystem (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [overlay];
          };
        in {
          results = listToAttrs (map (name: {
              name = removeSuffix ".nix" (baseNameOf name);
              value = evalChipsModules {
                inherit pkgs system;
                modules = modules ++ [name];
              };
            })
            nixFiles);
        }
      ))
      .results;

  useDockerImages = {
    dockerImagesDir,
    modules,
    overlay,
  }: let
    nixFiles = nixFilesIn dockerImagesDir;
  in
    with utils.lib;
      (eachDefaultSystem (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [overlay];
          };
        in {
          legacyPackages = foldl recursiveUpdate {} (map (nixFile: {
              dockerImages =
                (evalChipsModules {
                  inherit pkgs system;
                  modules = modules ++ [nixFile];
                })
                .dockerImages
                .output;
            })
            nixFiles);
        }
      ))
      .legacyPackages;

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
    specialArgs,
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
              specialArgs = specialArgs // {
                # expose `name` as an input to NixOS configurations
                name = configuration.name;
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
    dockerImagesDir ? null,
    nixosConfigurationsDir ? null,
    nixosSpecialArgs ? {},
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

    dockerImages = optionalAttrs (dockerImagesDir != null) (useDockerImages {
      inherit dockerImagesDir overlay;
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
      specialArgs = nixosSpecialArgs;
    });

    devShells = optionalAttrs (devShellsDir != null) (useDevShells {
      inherit devShellsDir overlay;
      modules =
        nixChipModules
        ++ nixosShimModules
        ++ sharedChipModules;
    });

    collectFromOutput = attrPath: output: let
      fromPath = getAttrFromPath attrPath;
    in
      mapAttrs (n: v: mapAttrs (n: cfg: fromPath cfg) v) output;

    devShellSecretsPerSystem = collectFromOutput ["arcanum" "secretRecipients"] devShells;
    devShellsSecretsFlat = flatten (mapAttrsToList (system: devShell: (mapAttrsToList (devShellName: secrets: secrets) devShell)) devShellSecretsPerSystem);
    mergedDevShellSecrets = foldAttrs (recipients: carry: unique (carry ++ recipients)) (arcanum.adminRecipients or []) devShellsSecretsFlat;
  in {
    inherit packages checks apps nixosConfigurations;
    devShells = collectFromOutput ["devShell" "output"] devShells;
    nixosModules.default = nixosModules ++ projectNixosModules;
    overlays.default = overlay;
    legacyPackages = dockerImages;
    lib = {
      devShellsSecrets = mergedDevShellSecrets;
      manual = mkManual {modules = mergedNixosModules;};
      arcanum =
        (chipsLib.recipientsFromConfigurations nixosConfigurations)
        // mergedDevShellSecrets
        // (mapAttrs' (name: file: nameValuePair file.source ((file.recipients or []) ++ arcanum.adminRecipients)) (arcanum.files or {}));
    };
  }
