{lib, ...}:
with lib; let
  recipientsFromConfigurations = nixosConfigurations: let
    adminRecipientsList = flatten (map (node: node.config.arcanum.adminRecipients) (attrValues nixosConfigurations));
    prefixRecipient = node: recipient:
      if hasPrefix "age" recipient
      then recipient
      else "${recipient} ${node.config.networking.hostName}";
    nodeSecretFilesList = map (node: mapAttrs' (n: file: nameValuePair file.source (map (prefixRecipient node) file.recipients)) node.config.arcanum.files) (attrValues nixosConfigurations);
    nodeSecretFilesAttrs = foldAttrs (recipients: carry: unique (carry ++ recipients)) adminRecipientsList nodeSecretFilesList;
  in
    nodeSecretFilesAttrs;
in {
  inherit recipientsFromConfigurations;
}
