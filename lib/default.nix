{
  self,
  nixpkgs,
  utils,
  ...
} @ inputs:
with nixpkgs.lib; {
  mergeOverlays = overlays: final: prev: (foldl' (p: next: p // (next final p)) prev overlays);
  use = import ./use.nix inputs;
  traefik = import ./traefik.nix {inherit (nixpkgs) lib;};
}
