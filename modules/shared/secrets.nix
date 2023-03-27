{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.secrets;

  secretFile = types.submodule {
    options = {
      source = mkOption {
        type = types.str;
        description = "path to encrypted secret relative to relativeRoot";
      };

      recipients = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "public keys to encrypt the secret for";
      };

      dest = mkOption {
        type = types.str;
        description = "where to write the decrypted secret to";
      };

      owner = mkOption {
        default = "root";
        type = types.str;
        description = "who should own the secret";
      };

      group = mkOption {
        default = "root";
        type = types.str;
        description = "what group should own the secret";
      };

      permissions = mkOption {
        default = "0400";
        type = types.str;
        description = "Permissions expressed as octal.";
      };

      makeDirectory = mkOption {
        default = false;
        type = types.bool;
        description = "Whether to create the directory if it doesn't exist.";
      };

      directoryPermissions = mkOption {
        default = "0555";
        type = types.nullOr types.str;
        description = "Permissions expressed as octal.";
      };
    };
  };
in {
  options = with types; {
    secrets = {
      relativeRoot = mkOption {
        type = path;
        description = "relative path to use for file sources";
      };
      adminRecipients = mkOption {
        type = listOf str;
        description = "public keys to include as recipients for all secrets";
        default = [];
      };
      files = mkOption {
        type = attrsOf secretFile;
        description = "secret configuration";
        default = {};
      };
      hostPublicKey = mkOption {
        type = str;
        description = "Host public key";
      };
      identity = mkOption {
        default = "/etc/ssh/ssh_host_ed25519_key";
        type = types.path;
        description = "Identity file to use for decryption.";
      };
    };
  };
}
