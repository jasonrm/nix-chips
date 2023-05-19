{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with types; let
  cfg = config.arcanum;

  secretFile = submodule {
    options = {
      source = mkOption {
        type = str;
        description = "path to encrypted secret relative to relativeRoot";
      };

      recipients = mkOption {
        type = listOf str;
        default = [];
        description = "public keys to encrypt the secret for";
      };

      dest = mkOption {
        type = str;
        description = "where to write the decrypted secret to";
      };

      owner = mkOption {
        default = "root";
        type = str;
        description = "who should own the secret";
      };

      group = mkOption {
        default = "root";
        type = str;
        description = "what group should own the secret";
      };

      permissions = mkOption {
        default = "0400";
        type = str;
        description = "Permissions expressed as octal.";
      };

      makeDirectory = mkOption {
        default = false;
        type = bool;
        description = "Whether to create the directory if it doesn't exist.";
      };

      directoryPermissions = mkOption {
        default = "0555";
        type = nullOr str;
        description = "Permissions expressed as octal.";
      };

      before = mkOption {
        type = listOf str;
        default = [];
        description = "Ensure this secret is decrypted before these services are started.";
      };
    };
  };
in {
  options = with types; {
    arcanum = {
      relativeRoot = mkOption {
        type = path;
        description = "relative path to use for file sources";
      };
      adminRecipients = mkOption {
        type = listOf str;
        description = "public keys to include as recipients for all secrets";
        default = [];
      };
      wellKnownRecipients = mkOption {
        type = attrsOf str;
        description = "public keys of well known recipients";
        default = {};
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

      secretRecipients = mkOption {
        type = nullOr attrs;
        default = {};
      };
    };
  };
}
