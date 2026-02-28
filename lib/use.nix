{
  self,
  nixpkgs,
  nixpkgs-staging,
  home-manager,
  utils,
  ...
}:
with nixpkgs.lib; let
  inherit (filesystem) listFilesRecursive;
  inherit (utils.lib) eachSystem eachDefaultSystem;

  onlyNix = baseName: (hasSuffix ".nix" baseName);
  nixFilesIn = directory: builtins.filter onlyNix (listFilesRecursive directory);

  nixFileName = path: removeSuffix ".nix" (baseNameOf path);

  pkgsFor = {
    system,
    overlay,
    nixpkgsConfig ? {},
  }:
    import nixpkgs {
      inherit system;
      config = nixpkgsConfig;
      overlays = [overlay];
    };

  callPackageFiles = pkgs: files:
    listToAttrs (map (path: nameValuePair (nixFileName path) (pkgs.callPackage path {})) files);

  nixChipModules = nixFilesIn ../modules/chips;
  nixosChipModules = nixFilesIn ../modules/nixos;
  nixosShimModules = nixFilesIn ../modules/nixos-shims;
  sharedChipModules = nixFilesIn ../modules/shared;
  homeManagerChipModules = nixFilesIn ../modules/home-manager;

  chipsAppsDir = nixFilesIn ../apps;

  # via: https://github.com/numtide/flake-utils/issues/16#issuecomment-1647192629
  # Another aux function, to merge two whole output sets. The key insight
  # is that we only merge recursively down to two levels.
  mergeOutputs = let
    inherit (builtins) length;
    inherit (nixpkgs.lib.attrsets) recursiveUpdateUntil;
    mergeDepth = depth:
      recursiveUpdateUntil (
        path: l: r:
          length path > depth
      );
  in
    builtins.foldl' (mergeDepth 2) {};

  useApps = {
    appsDir,
    overlay,
  }: let
    allApps =
      chipsAppsDir
      ++ (
        if appsDir != null
        then nixFilesIn appsDir
        else []
      );
  in
    (eachDefaultSystem (
      system: {
        apps = callPackageFiles (pkgsFor {inherit system overlay;}) allApps;
      }
    )).apps;

  mkPackagesOverlay = packagesDir: final: prev:
    callPackageFiles prev (
      if packagesDir != null
      then nixFilesIn packagesDir
      else []
    );

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
    }).config;

  useDevShells = {
    devShellsDir,
    nixpkgsConfig,
    modules,
    overlay,
  }: let
    nixFiles = nixFilesIn devShellsDir;
  in
    (eachDefaultSystem (
      system: let
        pkgs = pkgsFor {inherit system overlay nixpkgsConfig;};
      in {
        results = listToAttrs (
          map (name: {
            name = nixFileName name;
            value = evalChipsModules {
              inherit pkgs system;
              modules = modules ++ [name];
            };
          })
          nixFiles
        );
      }
    )).results;

  useDockerImages = {
    dockerImagesDir,
    modules,
    overlay,
  }: let
    nixFiles = nixFilesIn dockerImagesDir;
  in
    (eachDefaultSystem (
      system: let
        pkgs = pkgsFor {inherit system overlay;};
      in {
        legacyPackages = foldl recursiveUpdate {} (
          map (nixFile: {
            dockerImages =
              (evalChipsModules {
                inherit pkgs system;
                modules = modules ++ [nixFile];
              }).dockerImages.output;
          })
          nixFiles
        );
      }
    )).legacyPackages;

  usePackages = {
    packagesDir,
    overlay,
  }:
    (eachDefaultSystem (
      system: {
        packages = callPackageFiles (pkgsFor {inherit system overlay;}) (nixFilesIn packagesDir);
      }
    )).packages;

  useChecks = {
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
        pkgs = pkgsFor {inherit system overlay;};
      };
  in
    ((eachSystem [utils.lib.system.x86_64-linux]) (system: {
      checks = listToAttrs (
        map (check: {
          name = nixFileName check;
          value = makeCheck system check;
        })
        checks
      );
    })).checks;

  mkManual = {modules}:
    (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        (
          {...}: {
            config = {
              documentation.nixos.extraModules = map toString modules;
            };
          }
        )
      ];
    }).config.system.build.manual;

  useHomeConfigurations = {
    homeConfigurationsDir,
    nixpkgsConfig,
    modules,
    overlay,
    specialArgs ? {},
  }: let
    onlyHomeNix = baseName: (hasSuffix "home.nix" baseName);

    configurations = map (n: {
      name = builtins.baseNameOf (builtins.dirOf n);
      path = n;
    }) (builtins.filter onlyHomeNix (nixFilesIn homeConfigurationsDir));
  in
    (eachDefaultSystem (
      system: let
        pkgs = pkgsFor {inherit system overlay nixpkgsConfig;};
      in {
        results = {
          homeConfigurations = listToAttrs (
            map (
              configuration:
                nameValuePair configuration.name (
                  home-manager.lib.homeManagerConfiguration {
                    inherit pkgs;
                    extraSpecialArgs = specialArgs;
                    modules = modules ++ [configuration.path];
                  }
                )
            )
            configurations
          );
        };
      }
    )).results;

  useNixosConfigurations = {
    nixosConfigurationsDir,
    modules,
    overlay,
    specialArgs,
  }: let
    onlyDefaultNix = baseName: (hasSuffix "default.nix" baseName);

    allDefaultNix = builtins.filter onlyDefaultNix (nixFilesIn nixosConfigurationsDir);
    notDarwin = n: !(hasInfix "/darwin/" (toString n));

    configurations = map (n: {
      name = builtins.baseNameOf (builtins.dirOf n);
      system =
        if (hasInfix "/aarch64/" (toString n))
        then "aarch64-linux"
        else "x86_64-linux";
      path = n;
    }) (builtins.filter notDarwin allDefaultNix);

    nixosConfigurations = builtins.listToAttrs (
      map (
        configuration:
          nameValuePair configuration.name (
            nixpkgs.lib.nixosSystem {
              system = configuration.system;
              specialArgs =
                specialArgs
                // {
                  inherit home-manager sharedChipModules nixosShimModules;
                  # expose `name` as an input to NixOS configurations
                  name = configuration.name;
                  nodes = nixosConfigurations;
                };
              modules =
                [
                  (
                    {...}: {
                      config = {
                        nixpkgs.overlays = [overlay];
                      };
                    }
                  )
                ]
                ++ modules
                ++ [configuration.path];
            }
          )
      )
      configurations
    );
  in
    nixosConfigurations;

  useDarwinConfigurations = {
    nixosConfigurationsDir,
    darwinLib,
    modules,
    overlay,
    specialArgs,
    nixosConfigurations ? {},
  }: let
    onlyDefaultNix = baseName: (hasSuffix "default.nix" baseName);
    isDarwin = n: hasInfix "/darwin/" (toString n);

    configurations = map (n: {
      name = builtins.baseNameOf (builtins.dirOf n);
      system =
        if (hasInfix "/x86_64/" (toString n))
        then "x86_64-darwin"
        else "aarch64-darwin";
      path = n;
    }) (builtins.filter isDarwin (builtins.filter onlyDefaultNix (nixFilesIn nixosConfigurationsDir)));

    darwinConfigurations = builtins.listToAttrs (
      map (
        configuration:
          nameValuePair configuration.name (
            darwinLib.darwinSystem {
              system = configuration.system;
              specialArgs =
                specialArgs
                // {
                  inherit home-manager sharedChipModules nixosConfigurations;
                  name = configuration.name;
                  nodes = darwinConfigurations;
                };
              modules =
                [
                  (
                    {...}: {
                      config = {
                        nixpkgs.overlays = [overlay];
                      };
                    }
                  )
                ]
                ++ modules
                ++ [configuration.path];
            }
          )
      )
      configurations
    );
  in
    darwinConfigurations;
in
  {
    appsDir ? null,
    checksDir ? null,
    devShellsDir ? null,
    packagesDir ? null,
    nixosModulesDir ? null,
    dockerImagesDir ? null,
    nixosConfigurationsDir ? null,
    homeConfigurationsDir ? null,
    nixosSpecialArgs ? {},
    darwinLib ? null,
    darwinModules ? [],
    darwinSpecialArgs ? {},
    homeSpecialArgs ? {},
    nixosModules ? [],
    homeConfigurationModules ? [],
    overlays ? [],
    arcanum ? {},
    nixpkgsConfig ? {},
    additionalPackages ? (pkgs: {}),
    additionalApps ? (pkgs: {}),
    ...
  }: let
    projectNixosModules =
      if nixosModulesDir != null
      then nixFilesIn nixosModulesDir
      else [];

    mergedNixosModules = nixosChipModules ++ nixosModules ++ sharedChipModules ++ projectNixosModules;

    overlay = self.lib.mergeOverlays (
      overlays
      ++ [
        (mkPackagesOverlay packagesDir)
        nixpkgs-staging.overlays.default
      ]
    );

    packages = optionalAttrs (packagesDir != null) (usePackages {
      inherit overlay packagesDir;
    });

    dockerImages = optionalAttrs (dockerImagesDir != null) (useDockerImages {
      inherit dockerImagesDir overlay;
      modules = nixChipModules ++ nixosShimModules ++ sharedChipModules;
    });

    checks = optionalAttrs (checksDir != null) (useChecks {
      inherit self checksDir overlay;
      modules = mergedNixosModules;
    });

    apps = useApps {inherit appsDir overlay;};

    nixosConfigurations = optionalAttrs (nixosConfigurationsDir != null) (useNixosConfigurations {
      inherit nixosConfigurationsDir overlay;
      modules = mergedNixosModules;
      specialArgs = nixosSpecialArgs;
    });

    darwinConfigurations = optionalAttrs (nixosConfigurationsDir != null && darwinLib != null) (useDarwinConfigurations {
      inherit nixosConfigurationsDir darwinLib overlay nixosConfigurations;
      modules = darwinModules ++ sharedChipModules;
      specialArgs = darwinSpecialArgs;
    });

    homeConfigurations = optionalAttrs (homeConfigurationsDir != null) (useHomeConfigurations {
      inherit homeConfigurationsDir nixpkgsConfig overlay;
      specialArgs = homeSpecialArgs // {inherit nixosConfigurations darwinConfigurations;};
      modules = homeConfigurationModules ++ homeManagerChipModules ++ sharedChipModules;
    });

    devShells = optionalAttrs (devShellsDir != null) (useDevShells {
      inherit devShellsDir nixpkgsConfig overlay;
      modules = nixChipModules ++ nixosShimModules ++ sharedChipModules;
    });

    collectFromOutput = attrPath: output: let
      fromPath = getAttrFromPath attrPath;
    in
      mapAttrs (n: v: mapAttrs (n: cfg: fromPath cfg) v) output;

    additionalAttrs = eachDefaultSystem (
      system: let
        pkgs = pkgsFor {inherit system overlay nixpkgsConfig;};
      in {
        packages = additionalPackages pkgs;
        apps = additionalApps pkgs;
      }
    );

    chipsOutput = {
      inherit
        checks
        apps
        packages
        nixosConfigurations
        darwinConfigurations
        ;
      legacyPackages = dockerImages;
      devShells = collectFromOutput ["devShell" "output"] devShells;
      nixosModules.default = nixosModules ++ projectNixosModules;
      overlays.default = overlay;
      lib = {
        manual = mkManual {modules = mergedNixosModules;};
        arcanum = {
          nixos =
            mapAttrs (hostname: node: {
              inherit (node.config.arcanum) files adminRecipients;
            })
            nixosConfigurations;
          darwin =
            mapAttrs (hostname: node: {
              inherit (node.config.arcanum) files adminRecipients;
            })
            darwinConfigurations;
          devShells =
            mapAttrs (
              system: value:
                mapAttrs (userHost: config: {inherit (config.arcanum) files adminRecipients;}) value
            )
            devShells;
          homeManager =
            mapAttrs (
              name: home: (mapAttrs (name: user: {
                  inherit (user.config.arcanum) files adminRecipients;
                })
                home.homeConfigurations)
            )
            homeConfigurations;
          flake = {
            files = arcanum.files or {};
            adminRecipients = arcanum.adminRecipients or [];
          };
        };
      };
    };
  in
    mergeOutputs [
      {legacyPackages = homeConfigurations;}
      additionalAttrs
      chipsOutput
    ]
