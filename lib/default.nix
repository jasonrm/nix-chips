{nixpkgs, ...} @ inputs: {
  mkFlake = import ./mkFlake.nix inputs;
  traefik = import ./traefik.nix {inherit (nixpkgs) lib;};
  overlays = {
    unstable = throw "nix-chips: chips.lib.overlays.unstable was removed; pkgs.unstable is now provided automatically when your flake has a `nixpkgs-unstable` input (passed to mkFlake via `inherit inputs;`)";
  };
}
