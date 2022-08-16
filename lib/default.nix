{ lib }: let
  inherit (lib) assertMsg;

  impureEnv = env:
    let
      value = builtins.getEnv env;
    in
    assert assertMsg (builtins.stringLength value > 0)
      "Using ${env} requires the --impure flag to be used";
    value;
in {
  inherit impureEnv;
	traefik = import ./traefik.nix { inherit lib; };
}
