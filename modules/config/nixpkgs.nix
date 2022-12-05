{
  system,
  nixpkgs,
  overlays ? [],
  ...
}: {
  _module.args = {
    pkgs = import nixpkgs {
      inherit system;
      inherit overlays;
      config.allowUnfree = true;
    };
  };
}
