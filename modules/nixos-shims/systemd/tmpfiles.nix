{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; let
  inherit (pkgs) path callPackage writeText;
  systemdTmpfiles = callPackage "${path}/nixos/modules/system/boot/systemd/tmpfiles.nix" {
    utils = callPackage "${path}/nixos/lib/utils.nix" {};
  };
  tmpFilesRules = writeText "tmpfiles.conf" (concatStringsSep "\n" config.systemd.tmpfiles.rules);
in {
  options = systemdTmpfiles.options;
  config = {
    devShell.shellHooks = ''
      ${pkgs.systemd-tmpfiles}/bin/systemd-tmpfiles --prefix "${config.dir.data}" "${tmpFilesRules}"
    '';
  };
}
