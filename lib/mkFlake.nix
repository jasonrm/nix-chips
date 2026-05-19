chipsInputs @ {nixpkgs, ...}: context: args: let
  lib = nixpkgs.lib;

  evaluated = lib.evalModules {
    modules = [
      ./flakeOptions.nix
      {config = args;}
    ];
    specialArgs = {
      inherit chipsInputs context;
    };
  };
in
  import ./flakeOutputs.nix chipsInputs context evaluated.config
