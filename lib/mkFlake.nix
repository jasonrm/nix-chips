chipsInputs @ {nixpkgs, ...}: args: let
  evaluated = nixpkgs.lib.evalModules {
    modules = [
      ./flakeOptions.nix
      {config = args;}
    ];
  };
in
  import ./flakeOutputs.nix chipsInputs evaluated.config
