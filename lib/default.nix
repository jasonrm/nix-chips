{
  nixpkgs,
  nixpkgs-unstable,
  ...
} @ inputs:
with nixpkgs.lib; {
  mergeOverlays = overlays: final: prev: (foldl' (p: next: p // (next final p)) prev overlays);
  use = import ./use.nix inputs;
  traefik = import ./traefik.nix {inherit (nixpkgs) lib;};
  overlays = {
    unstable = self: super: {
      unstable = nixpkgs-unstable.legacyPackages.${super.stdenv.hostPlatform.system};
    };
  };
}
