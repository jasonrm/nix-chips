{
  nixpkgs,
  nixpkgs-unstable,
  ...
} @ inputs: {
  mkFlake = import ./mkFlake.nix inputs;
  traefik = import ./traefik.nix {inherit (nixpkgs) lib;};
  overlays = {
    unstable = final: prev: {
      unstable = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
    };
  };
}
