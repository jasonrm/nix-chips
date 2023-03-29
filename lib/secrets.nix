{lib, ...}: let
  inherit (lib) attrValues flatten foldAttrs mapAttrs' nameValuePair unique hasPrefix;

  recipientsFromConfigurations = nixosConfigurations: let
    adminRecipientsList = flatten (map (node: node.config.secrets.adminRecipients) (attrValues nixosConfigurations));
    prefixRecipient = node: recipient: if hasPrefix "age" then recipient else "${recipient} ${node.config.networking.hostName}";
    nodeSecretFilesList = map (node: mapAttrs' (n: file: nameValuePair file.source (map (prefixRecipient node) file.recipients)) node.config.secrets.files) (attrValues nixosConfigurations);
    nodeSecretFilesAttrs = foldAttrs (recipients: carry: unique (carry ++ recipients)) adminRecipientsList nodeSecretFilesList;
  in
    nodeSecretFilesAttrs;
in {
  inherit recipientsFromConfigurations;
}
