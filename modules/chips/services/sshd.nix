{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.sshd;
in {
  options = {
    services.sshd = {
      enable = lib.mkEnableOption "enable sshd";
      # bindAddress = lib.mkOption {
      #   type = lib.types.str;
      #   default = "0.0.0.0";
      # };
      # smtpPort = lib.mkOption {
      #   type = lib.types.int;
      #   default = config.ports.mailhogSmtp;
      # };
      # httpPort = lib.mkOption {
      #   type = lib.types.int;
      #   default = config.ports.mailhogHttp;
      # };
      # hostname = lib.mkOption {
      #   type = lib.types.str;
      #   default = "mailhog.test";
      # };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      dockerImages.baseContents = [pkgs.openssh];
      programs.supervisord.programs.sshd = {
        command = ''
          ${pkgs.openssh}/bin/sshd -D -e
        '';
      };
    })
  ];
}
