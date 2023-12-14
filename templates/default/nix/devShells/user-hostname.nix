{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./default.nix
  ];

  config = {
    dir.project = "$PWD";

    arcanum.defaultRecipients = [
      # add output from `ssh-add -L` here, or `curl https://github.com/<username>.keys`
    ];
  };
}
