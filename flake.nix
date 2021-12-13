{
  description = "dev.mcneil.nix.nix-chips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
  };

  outputs = { self, nixpkgs, utils, nixpkgs-staging }:
    let
      inherit (nixpkgs.lib) evalModules hasSuffix;
      inherit (nixpkgs.lib.filesystem) listFilesRecursive;
      inherit (utils.lib) eachDefaultSystem;

      onlyNix = baseName: (hasSuffix ".nix" baseName);

      nixosModule = {
        imports = [
          (nixpkgs + "/nixos/modules/misc/assertions.nix")
          (nixpkgs + "/nixos/modules/services/databases/redis.nix")
          (nixpkgs + "/nixos/modules/services/web-servers/tomcat.nix")
        ] ++ (builtins.filter onlyNix (listFilesRecursive ./modules));
      };

      outputs = (eachDefaultSystem (system: (evalModules {
        specialArgs = { inherit nixpkgs system nixpkgs-staging; };
        modules = [
          nixosModule
          # ./examples/nginx-php-mysql.nix
        ];
      }).config.outputs));
    in
    outputs // {
      inherit nixosModule;
    };
}
