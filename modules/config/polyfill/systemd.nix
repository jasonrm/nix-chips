{ lib, pkgs, config, ... }:
let
  inherit (lib) mkDefault mkOption mapAttrs;
  inherit (pkgs) writeShellScriptBin;

  cfg = config.systemd.services;

  systemd = pkgs.callPackage (pkgs.path + "/nixos/modules/system/boot/systemd-unit-options.nix") {};

  makeCommand = name: service: writeShellScriptBin "exec.sh" ''
    # preStart
    ${service.preStart}
    # ExecStart
    exec ${service.serviceConfig.ExecStart}
  '';

  programFromService = name: service: {
    command = mkDefault "${makeCommand name service}/bin/exec.sh";
    # environment = mkDefault service.serviceConfig.Environment;
  };
in
{
  imports = [
  ];

  options = with lib.types; {
    systemd.services = mkOption {
      default = {};
      type = with systemd; attrsOf (submodule [ { options = serviceOptions; } ]);
    };
  };

  config = {
    programs.supervisord.enable = true;
    programs.supervisord.programs = mapAttrs programFromService config.systemd.services;
  };
}
