{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.arcanum;
in {
  config = {
    devShell.contents = [
      pkgs.arcanum
    ];

    arcanum.secretRecipients = mapAttrs' (name: secret: nameValuePair secret.source (secret.recipients ++ cfg.adminRecipients)) cfg.files;
  };
}
