{
  self,
  nixpkgs,
  nixpkgs-staging,
  rust-overlay,
  home-manager,
  utils,
  ...
}: cfg:
with nixpkgs.lib; let
  inherit (utils.lib) eachSystem;
  inherit (import ./discovery.nix {lib = nixpkgs.lib;}) devShellName nixFileName nixFilesIn;

  contextInputs = cfg.inputs;
  projectSelf = contextInputs.self or self;
  chipsSelf = contextInputs.chips or self;
  eachSupportedSystem = eachSystem cfg.systems;

  pkgsFor = system:
    import nixpkgs {
      inherit system;
      config = cfg.nixpkgs.config;
      overlays = [overlay];
    };

  callPackageFiles = pkgs: files:
    listToAttrs (map (path: nameValuePair (nixFileName path) (pkgs.callPackage path {})) files);

  filesOrEmpty = directory:
    if directory != null
    then nixFilesIn directory
    else [];

  nixChipModules = nixFilesIn ../modules/chips;
  nixosChipModules = nixFilesIn ../modules/nixos;
  nixosShimModules = nixFilesIn ../modules/nixos-shims;
  darwinChipModules = nixFilesIn ../modules/nix-darwin;
  sharedChipModules = nixFilesIn ../modules/shared;
  homeManagerChipModules = nixFilesIn ../modules/home-manager;

  chipsAppsDir = nixFilesIn ../apps;

  # via: https://github.com/numtide/flake-utils/issues/16#issuecomment-1647192629
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

  useApps = appsDir: let
    allApps = chipsAppsDir ++ filesOrEmpty appsDir;
  in
    (eachSupportedSystem (
      system: {
        apps = callPackageFiles (pkgsFor system) allApps;
      }
    )).apps;

  mkPackagesOverlay = packagesDir: final: prev:
    callPackageFiles prev (filesOrEmpty packagesDir);

  evalChipsModules = {
    pkgs,
    system,
    modules ? [],
  }:
    (evalModules {
      inherit modules;
      specialArgs = {
        inherit pkgs system;
        chips = chipsSelf;
        modulesPath = pkgs.path + "/nixos/modules";
      };
    }).config;

  useDevShells = {
    devShellsDir,
    modules,
    aliases ? {},
  }: let
    nixFiles = nixFilesIn devShellsDir;
  in
    (eachSupportedSystem (
      system: let
        pkgs = pkgsFor system;
        shells = listToAttrs (
          map (name: {
            name = devShellName devShellsDir name;
            value = evalChipsModules {
              inherit pkgs system;
              modules = modules ++ [name];
            };
          })
          nixFiles
        );
      in {
        results =
          shells
          // mapAttrs (
            alias: target:
              shells.${target} or (throw "devShells.aliases.${alias} points at unknown devShell '${target}'")
          )
          aliases;
      }
    )).results;

  useDockerImages = {
    dockerImagesDir,
    modules,
  }: let
    nixFiles = nixFilesIn dockerImagesDir;
  in
    (eachSupportedSystem (
      system: let
        pkgs = pkgsFor system;
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

  usePackages = packagesDir:
    (eachSupportedSystem (
      system: {
        packages = callPackageFiles (pkgsFor system) (nixFilesIn packagesDir);
      }
    )).packages;

  useChecks = {
    checksDir,
    modules,
  }: let
    checks = nixFilesIn checksDir;
    makeCheck = system: check:
      (import ./makeCheck.nix) (import check) {
        self = {
          nixosModules.default = modules;
          overlays.default = overlay;
        };
        pkgs = pkgsFor system;
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
    modules,
    specialArgs ? {},
  }: let
    onlyHomeNix = path: hasSuffix "home.nix" (baseNameOf path);

    configurations = map (n: {
      name = builtins.baseNameOf (builtins.dirOf n);
      path = n;
    }) (builtins.filter onlyHomeNix (nixFilesIn homeConfigurationsDir));
  in
    (eachSupportedSystem (
      system: let
        pkgs = pkgsFor system;
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
    specialArgs,
  }: let
    onlyDefaultNix = path: hasSuffix "default.nix" (baseNameOf path);

    allDefaultNix = builtins.filter onlyDefaultNix (nixFilesIn nixosConfigurationsDir);
    configurations =
      map (n: {
        name = builtins.baseNameOf (builtins.dirOf n);
        system =
          if hasInfix "/aarch64/" (toString n)
          then "aarch64-linux"
          else "x86_64-linux";
        path = n;
      })
      allDefaultNix;

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
    darwinConfigurationsDir,
    darwinLib,
    modules,
    specialArgs,
    nixosConfigurations ? {},
  }: let
    onlyDefaultNix = path: hasSuffix "default.nix" (baseNameOf path);

    configurations = map (n: {
      name = builtins.baseNameOf (builtins.dirOf n);
      system =
        if hasInfix "/x86_64/" (toString n)
        then "x86_64-darwin"
        else "aarch64-darwin";
      path = n;
    }) (builtins.filter onlyDefaultNix (nixFilesIn darwinConfigurationsDir));

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

  projectNixosModules = filesOrEmpty cfg.sources.nixosModules;

  mergedNixosModules = nixosChipModules ++ cfg.modules.nixos ++ sharedChipModules ++ projectNixosModules;

  overlay = composeManyExtensions (
    [
      (mkPackagesOverlay cfg.sources.packages)
      rust-overlay.overlays.default
      nixpkgs-staging.overlays.default
    ]
    ++ cfg.nixpkgs.overlays
  );

  packages = optionalAttrs (cfg.sources.packages != null) (usePackages cfg.sources.packages);

  dockerImages = optionalAttrs (cfg.sources.dockerImages != null) (useDockerImages {
    dockerImagesDir = cfg.sources.dockerImages;
    modules = nixChipModules ++ nixosShimModules ++ sharedChipModules;
  });

  checks = optionalAttrs (cfg.sources.checks != null) (useChecks {
    checksDir = cfg.sources.checks;
    modules = mergedNixosModules;
  });

  apps = useApps cfg.sources.apps;

  nixosConfigurations = optionalAttrs (cfg.sources.nixosConfigurations != null) (useNixosConfigurations {
    nixosConfigurationsDir = cfg.sources.nixosConfigurations;
    modules = mergedNixosModules;
    specialArgs = cfg.specialArgs.nixos;
  });

  darwinConfigurations = optionalAttrs (cfg.sources.darwinConfigurations != null && cfg.darwin.lib != null) (useDarwinConfigurations {
    inherit nixosConfigurations;
    darwinConfigurationsDir = cfg.sources.darwinConfigurations;
    darwinLib = cfg.darwin.lib;
    modules = darwinChipModules ++ cfg.modules.darwin ++ sharedChipModules;
    specialArgs = cfg.specialArgs.darwin;
  });

  homeConfigurations = optionalAttrs (cfg.sources.homeConfigurations != null) (useHomeConfigurations {
    homeConfigurationsDir = cfg.sources.homeConfigurations;
    specialArgs = cfg.specialArgs.home // {inherit nixosConfigurations darwinConfigurations;};
    modules = cfg.modules.home ++ homeManagerChipModules ++ sharedChipModules;
  });

  devShells = optionalAttrs (cfg.sources.devShells != null) (useDevShells {
    devShellsDir = cfg.sources.devShells;
    modules = nixChipModules ++ nixosShimModules ++ sharedChipModules;
    aliases = cfg.devShells.aliases;
  });

  collectFromOutput = attrPath: output: let
    fromPath = getAttrFromPath attrPath;
  in
    mapAttrs (n: v: mapAttrs (n: cfg: fromPath cfg) v) output;

  perSystemAttrs = eachSupportedSystem (
    system: let
      pkgs = pkgsFor system;
    in
      cfg.perSystem {
        inherit pkgs system;
        inputs = contextInputs;
        self = projectSelf;
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
    nixosModules.default = cfg.modules.nixos ++ projectNixosModules;
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
          files = cfg.arcanum.files or {};
          adminRecipients = cfg.arcanum.adminRecipients or [];
        };
      };
    };
  };
in
  mergeOutputs [
    {legacyPackages = homeConfigurations;}
    perSystemAttrs
    chipsOutput
    cfg.outputs
  ]
