{lib, ...}: let
  inherit (lib) attrValues flatten foldAttrs mapAttrs' nameValuePair unique;

  recipientsFromConfigurations = nixosConfigurations: let
    adminRecipientsList = flatten (map (node: node.config.secrets.adminRecipients) (attrValues nixosConfigurations));
    nodeSecretFilesList = map (node: mapAttrs' (n: file: nameValuePair file.source (map (r: "${r} ${node.config.networking.hostName}") file.recipients)) node.config.secrets.files) (attrValues nixosConfigurations);
    nodeSecretFilesAttrs = foldAttrs (recipients: carry: unique (carry ++ recipients)) adminRecipientsList nodeSecretFilesList;
  in
    nodeSecretFilesAttrs;
in {
  inherit recipientsFromConfigurations;
}
