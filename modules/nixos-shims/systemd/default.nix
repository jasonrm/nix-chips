{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  configShim = {
    systemd.path = "/dev/null";
    # systemd doesn't work on non-linux so we need to replace it
    # with a harmless package that can be in the path of the supervisord programs
    systemd.package = pkgs.hello;
  };

  utils = pkgs.callPackage "${pkgs.path}/nixos/lib/utils.nix" {config = configShim;};

  systemdBootModule = pkgs.callPackage "${pkgs.path}/nixos/modules/system/boot/systemd.nix" {
    config = configShim;
    inherit utils;
  };
in {
  # Copied from nixos/modules/system/boot/systemd.nix
  options = systemdBootModule.options;
}
