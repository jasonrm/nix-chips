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
    default = self: super: let
      unstable = nixpkgs-unstable.legacyPackages.${super.system};
    in {
      inherit unstable;
      mago = unstable.mago.override {
        rustPlatform =
          unstable.rustPlatform
          // {
            buildRustPackage = args:
              unstable.rustPlatform.buildRustPackage (
                args
                // rec {
                  pname = "mago";
                  version = "1.0.0-beta.5";
                  src = unstable.fetchFromGitHub {
                    owner = "carthage-software";
                    repo = pname;
                    tag = version;
                    hash = "sha256-OjCFUlcslkKBTPW/1W3pmhlO7moRse9t70xDk0jLQbM=";
                  };

                  cargoHash = "sha256-ZfmAjnZuu53SoGRWgWN/JwAMT+d/8WitFwP9+gURKhw=";
                }
              );
          };
      };
    };
  };
}
