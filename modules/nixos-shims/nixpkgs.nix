{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    nixpkgs = {
      config = mkOption {
        type = attrs;
      };
    };
  };
}
