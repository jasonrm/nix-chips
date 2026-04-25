{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.project;

  # Deterministic per-project IP in 127.0.0.0/8, derived from project.name.
  # Avoids 127.0.0.0 and 127.0.0.1 by clamping the last octet to [2, 254].
  hashedAddress = name: let
    hash = builtins.hashString "sha256" name;
    byteAt = i: lib.fromHexString (builtins.substring (i * 2) 2 hash);
    last = lib.mod (byteAt 2) 253 + 2;
  in "127.${toString (byteAt 0)}.${toString (byteAt 1)}.${toString last}";
in {
  imports = [];

  options = with types; {
    project = {
      name = mkOption {type = str;};
      domainSuffix = mkOption {
        type = str;
        default = "bitnix.dev";
      };
      address = mkOption {
        type = str;
        default = hashedAddress cfg.name;
        defaultText = "deterministic hash of project.name within 127.0.0.0/8";
        description = "Loopback address for this project. Must be in 127.0.0.0/8. Defaults to a deterministic hash of project.name so each project gets a unique loopback alias.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.hasPrefix "127." cfg.address;
        message = "project.address must be in the 127.0.0.0/8 range, got: ${cfg.address}";
      }
    ];

    devShell = {
      environment = [
        "DOMAIN_SUFFIX=${cfg.domainSuffix}"
        "LOOPBACK_ADDRESS=${cfg.address}"
      ];
    };
  };
}
