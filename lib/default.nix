{
  pkgs,
  lib,
}: let
  inherit (lib) assertMsg;

  impureEnv = builtins.getEnv;

  requireImpureEnv = env: let
    value = builtins.getEnv env;
  in
    assert assertMsg (builtins.stringLength value > 0)
    "Either ${env} is unset, or the --impure flag was not used with nix."; value;
in {
  inherit impureEnv;
  inherit requireImpureEnv;
  traefik = import ./traefik.nix {inherit lib;};
  generators = import ./generators.nix {inherit pkgs lib;};
  secrets = import ./secrets.nix {inherit pkgs lib;};
}
