{ system, nixpkgs, nixpkgs-staging, ... }:
let

  defaultOverlay = self: super: {
    # watchexec = super.watchexec.overrideAttrs (old: rec {
    #   version = "1.15.1";
    #   src = super.fetchFromGitHub {
    #     owner = old.pname;
    #     repo = old.pname;
    #     rev = version;
    #     sha256 = "1xznhfljvsvc0ykv5h1wg31n93v96lvhbxfhavxivq3b0xh5vxrw";
    #   };
    #   cargoSha256 = "00dampnsnpzmchjcn0j5zslx17i0qgrv99gq772n0683m1l2lfq3";
    # });
  };
in
{
  _module.args = {
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ nixpkgs-staging.overlay defaultOverlay ];
      config.allowUnfree = true;
    };
  };
}
