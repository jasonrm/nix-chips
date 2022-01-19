{ system, nixpkgs, nixpkgs-staging, ... }:
let

  defaultOverlay = self: super: {
    mysql80 = super.mysql80.overrideAttrs (old: rec {

      patches = [
        (super.fetchpatch {
          url = "https://raw.githubusercontent.com/Homebrew/formula-patches/fcbea58e245ea562fbb749bfe6e1ab178fd10025/mysql/monterey.diff";
          sha256 = "sha256-K1NBjaPRSftgsCRWN+JBZjNTeljkLmxCBSPJW4nSgkg=";
        })
      ];
    });

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
