{ system, nixpkgs, nixpkgs-staging, ... }:
{
  _module.args = {
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ nixpkgs-staging.overlay ];
      config.allowUnfree = true;
    };
  };
}
