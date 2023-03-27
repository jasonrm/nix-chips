{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.secrets;
in {
  config = {
    secrets = {
      adminRecipients = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ3k6zKT97l8vlxcmH5hekHEvnSDXpL6j8FFW/ZL3CXT jasonrm@raskin"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5gspOWcPeO/Qol7NbmvKIN8iQtGBYqhtPWwJMLSpYo jasonrm@elon"
      ];
      files = {
        testing = {
          source = "secrets/testing.age";
        };
      };
    };

    outputs = {
      secretRecipients = mapAttrs' (name: secret: nameValuePair secret.source (secret.recipients ++ cfg.adminRecipients)) cfg.files;
    };
  };
}
