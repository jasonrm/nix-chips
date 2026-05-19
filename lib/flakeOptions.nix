{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    sources = {
      apps = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing app definitions.";
      };

      checks = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing NixOS test check definitions.";
      };

      devShells = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing development shell configurations.";
      };

      packages = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing package definitions and overlay packages.";
      };

      dockerImages = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing Docker image configurations.";
      };

      nixosModules = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing additional NixOS modules exported by this flake.";
      };

      nixosConfigurations = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing NixOS system configurations.";
      };

      darwinConfigurations = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing nix-darwin system configurations.";
      };

      homeConfigurations = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing Home Manager configurations.";
      };
    };

    nixpkgs = {
      config = mkOption {
        type = types.attrs;
        default = {};
        description = "Nixpkgs configuration passed to imported package sets.";
      };

      overlays = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "Nixpkgs overlays applied to all package sets.";
      };
    };

    modules = {
      nixos = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "Additional NixOS modules included in NixOS configurations and checks.";
      };

      darwin = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "Additional nix-darwin modules included in darwin configurations.";
      };

      home = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "Additional Home Manager modules included in home configurations.";
      };
    };

    specialArgs = {
      nixos = mkOption {
        type = types.attrs;
        default = {};
        description = "Extra specialArgs passed to NixOS system evaluations.";
      };

      darwin = mkOption {
        type = types.attrs;
        default = {};
        description = "Extra specialArgs passed to nix-darwin system evaluations.";
      };

      home = mkOption {
        type = types.attrs;
        default = {};
        description = "Extra specialArgs passed to Home Manager evaluations.";
      };
    };

    darwin.lib = mkOption {
      type = types.nullOr types.raw;
      default = null;
      description = "nix-darwin library, usually nix-darwin.lib.";
    };

    arcanum = mkOption {
      type = types.attrs;
      default = {};
      description = "Arcanum secret metadata exported under lib.arcanum.flake.";
    };

    perSystem = mkOption {
      type = types.functionTo types.attrs;
      default = {
        pkgs,
        system,
        ...
      }: {};
      description = "Function producing additional per-system flake outputs such as packages and apps.";
    };
  };
}
