{
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  systemdTmpfiles = pkgs.callPackage "${pkgs.path}/nixos/modules/system/boot/systemd/tmpfiles.nix" {
    utils = pkgs.callPackage "${pkgs.path}/nixos/lib/utils.nix" {};
  };
in {
  options = systemdTmpfiles.options;
}
