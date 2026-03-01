{
  pkgs,
  lib,
  self,
}:
let
  inherit (lib.filesystem) listFilesRecursive;

  onlyNix = baseName: (lib.hasSuffix ".nix" baseName);
  nixFilesIn = directory: builtins.filter onlyNix (listFilesRecursive directory);

  nixChipModules = nixFilesIn ../modules/chips;
  nixosShimModules = nixFilesIn ../modules/nixos-shims;
  sharedChipModules = nixFilesIn ../modules/shared;

  repoRoot = toString ../.;

  compatLib = lib // { mdDoc = lib.id; };

  evaluated = lib.evalModules {
    modules = nixChipModules ++ nixosShimModules ++ sharedChipModules ++ [
      ({ ... }: { _module.check = false; })
    ];
    specialArgs = {
      inherit pkgs;
      lib = compatLib;
      system = pkgs.stdenv.hostPlatform.system;
      chips = self;
      modulesPath = pkgs.path + "/nixos/modules";
    };
  };

  transformDecl = decl:
    let declStr = toString decl;
    in
      if lib.hasPrefix repoRoot declStr
      then lib.removePrefix (repoRoot + "/") declStr
      else declStr;

  # Simple option extractor that avoids deep thunks
  # Returns { ok = true; value = ...; } or { ok = false; }
  safeGetDefault = opt:
    let
      tried = builtins.tryEval (
        if !(opt ? default) then { ok = false; }
        else let
          v = builtins.tryEval opt.default;
        in
          if !v.success then { ok = true; value = "«error»"; }
          else if builtins.isFunction v.value then { ok = true; value = "«function»"; }
          else
            # Try to verify it's serializable
            let j = builtins.tryEval (builtins.toJSON v.value);
            in
              if j.success then { ok = true; value = v.value; }
              else { ok = true; value = "«complex»"; }
      );
    in
      if tried.success then tried.value else { ok = false; };

  safeGetType = opt:
    let tried = builtins.tryEval (opt.type.description or "unknown");
    in if tried.success then tried.value else "unknown";

  safeGetDesc = opt:
    let tried = builtins.tryEval (
      if opt ? description && builtins.isString opt.description
      then opt.description
      else ""
    );
    in if tried.success then tried.value else "";

  safeGetReadOnly = opt:
    let tried = builtins.tryEval (opt.readOnly or false);
    in if tried.success then tried.value else false;

  safeGetDecls = opt:
    let tried = builtins.tryEval (map transformDecl (opt.declarations or []));
    in if tried.success then tried.value else [];

  isChipsDecl = d:
    lib.hasPrefix "modules/chips/" d
    || lib.hasPrefix "modules/shared/" d
    || lib.hasPrefix "modules/nixos/" d
    || lib.hasPrefix "modules/home-manager/" d;

  # Walk options tree (limited depth, limited scope)
  walkOptions = depth: prefix: tree:
    if depth > 6 then {}
    else
      let
        namesTried = builtins.tryEval (builtins.attrNames tree);
        names = if namesTried.success then namesTried.value else [];
      in
        builtins.foldl' (acc: name:
          let
            valTried = builtins.tryEval tree.${name};
          in
            if !valTried.success then acc
            else
              let
                val = valTried.value;
                fullName = if prefix == "" then name else "${prefix}.${name}";
                isOptTried = builtins.tryEval (val ? _type && val._type == "option");
                isOpt = isOptTried.success && isOptTried.value;
              in
                if isOpt then
                  let
                    decls = safeGetDecls val;
                    hasChips = builtins.any isChipsDecl decls;
                  in
                    if hasChips then
                      let def = safeGetDefault val;
                      in acc // {
                        ${fullName} = {
                          declarations = decls;
                          type = safeGetType val;
                          description = safeGetDesc val;
                          readOnly = safeGetReadOnly val;
                        } // lib.optionalAttrs def.ok {
                          default = def.value;
                        };
                      }
                    else acc
                else
                  let
                    isAttrsTried = builtins.tryEval (builtins.isAttrs val && !(val ? _type));
                  in
                    if isAttrsTried.success && isAttrsTried.value then
                      let
                        subTried = builtins.tryEval (walkOptions (depth + 1) fullName val);
                      in
                        if subTried.success then acc // subTried.value else acc
                    else acc
        ) {} names;

  # Only walk trees with chips-declared options
  relevantOpts = lib.filterAttrs (n: _: builtins.elem n [
    "arcanum" "devShell" "dir" "dockerImages" "ports"
    "programs" "project"
  ]) evaluated.options;

  allOptions = walkOptions 0 "" relevantOpts;

  # Filter out internal options
  documentableOptions = lib.filterAttrs (name: _:
    !(lib.hasPrefix "_" name)
  ) allOptions;

  # lib.use parameters
  useFunction = import ../lib/use.nix {
    inherit self;
    inherit (self.inputs) nixpkgs nixpkgs-staging home-manager utils;
  };

  useFunctionArgs = builtins.functionArgs useFunction;

  useParamDescriptions = {
    appsDir = "Directory containing app definitions (*.nix files)";
    checksDir = "Directory containing NixOS test check definitions";
    devShellsDir = "Directory containing development shell configurations";
    packagesDir = "Directory containing package definitions";
    nixosModulesDir = "Directory containing additional NixOS modules";
    dockerImagesDir = "Directory containing Docker image configurations";
    nixosConfigurationsDir = "Directory containing NixOS system configurations";
    homeConfigurationsDir = "Directory containing Home Manager configurations";
    nixosSpecialArgs = "Extra arguments passed to NixOS system evaluations";
    darwinLib = "nix-darwin library (e.g., nix-darwin.lib) for macOS support";
    darwinModules = "Additional nix-darwin modules to include";
    darwinSpecialArgs = "Extra arguments passed to nix-darwin evaluations";
    homeSpecialArgs = "Extra arguments passed to Home Manager evaluations";
    nixosModules = "Additional NixOS modules to include in all configurations";
    homeConfigurationModules = "Additional Home Manager modules to include";
    overlays = "List of nixpkgs overlays to apply";
    arcanum = "Arcanum secret management configuration";
    nixpkgsConfig = "Nixpkgs configuration (e.g., allowUnfree)";
    additionalPackages = "Function (pkgs -> attrset) returning extra packages";
    additionalApps = "Function (pkgs -> attrset) returning extra apps";
  };

  useParams = lib.mapAttrs (name: hasDefault: {
    inherit hasDefault;
    description = useParamDescriptions.${name} or "No description available";
    type =
      if builtins.elem name ["appsDir" "checksDir" "devShellsDir" "packagesDir" "nixosModulesDir" "dockerImagesDir" "nixosConfigurationsDir" "homeConfigurationsDir"]
      then "path or null"
      else if builtins.elem name ["nixosSpecialArgs" "darwinSpecialArgs" "homeSpecialArgs" "nixpkgsConfig" "arcanum"]
      then "attribute set"
      else if builtins.elem name ["darwinModules" "nixosModules" "homeConfigurationModules" "overlays"]
      then "list"
      else if builtins.elem name ["additionalPackages" "additionalApps"]
      then "function"
      else if name == "darwinLib"
      then "nix-darwin lib or null"
      else "unknown";
    default =
      if builtins.elem name ["appsDir" "checksDir" "devShellsDir" "packagesDir" "nixosModulesDir" "dockerImagesDir" "nixosConfigurationsDir" "homeConfigurationsDir" "darwinLib"]
      then "null"
      else if builtins.elem name ["nixosSpecialArgs" "darwinSpecialArgs" "homeSpecialArgs" "nixpkgsConfig"]
      then "{}"
      else if builtins.elem name ["darwinModules" "nixosModules" "homeConfigurationModules" "overlays"]
      then "[]"
      else if builtins.elem name ["arcanum"]
      then "{}"
      else if builtins.elem name ["additionalPackages" "additionalApps"]
      then "(pkgs: {})"
      else null;
  }) useFunctionArgs;

  optionsJsonFile = pkgs.writeText "options.json" (builtins.toJSON documentableOptions);
  useParamsJsonFile = pkgs.writeText "use-params.json" (builtins.toJSON useParams);

  splitScript = ./split-options.ts;
in
pkgs.runCommand "docs-data" {
  nativeBuildInputs = [ pkgs.bun ];
} ''
  mkdir -p $out

  cp ${optionsJsonFile} $out/options.json

  mkdir -p $out/lib
  cp ${useParamsJsonFile} $out/lib/use.json

  cd $out
  ${pkgs.bun}/bin/bun run ${splitScript} $out/options.json $out
''
