{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption;

  cfg = config.services.haproxy;

  haproxyCfg = pkgs.writeText "haproxy.conf" ''
    global
      log stdout format raw local0 info

    ${cfg.config}
  '';

  haproxy-debug = pkgs.writeShellScriptBin "haproxy-debug" ''
    cat ${haproxyCfg}
  '';
in {
  imports = [];

  config = lib.mkIf cfg.enable {
    programs.supervisord.programs.haproxy = {
      command =
        if pkgs.stdenv.isDarwin
        then "sudo -E ${pkgs.haproxy}/sbin/haproxy -W -f ${haproxyCfg}"
        else "${pkgs.haproxy}/sbin/haproxy -W -f ${haproxyCfg}";
    };
    devShell = {
      contents = [haproxy-debug];
    };
  };
}
