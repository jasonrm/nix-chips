{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.project;
  isDarwin = pkgs.stdenv.isDarwin;

  resolverFile = "/etc/resolver/${cfg.domainSuffix}";
  resolverContent = "nameserver ${cfg.address}\nport ${toString config.ports.dns}";

  dns-setup = pkgs.writeShellScriptBin "dns-setup" (
    if isDarwin
    then ''
      set -euo pipefail

      expected=$(printf '%s\n' "${resolverContent}")

      if [ -f "${resolverFile}" ] && [ "$(cat "${resolverFile}")" = "$expected" ]; then
        echo "Resolver file ${resolverFile} already up to date"
      else
        echo "Creating ${resolverFile}..."
        printf '%s\n' "$expected" | sudo tee "${resolverFile}" > /dev/null
        echo "Done."
      fi
    ''
    else ''
      set -euo pipefail

      echo "DNS resolver setup is only automated on macOS."
      echo "On Linux, configure your system DNS to resolve *.${cfg.domainSuffix} to ${cfg.address} (port ${toString config.ports.dns})."
    ''
  );
in {
  options.project.dns = {
    enable = lib.mkEnableOption "local DNS resolution via dnsmasq";
  };

  config = lib.mkIf cfg.dns.enable (lib.mkMerge [
    {
      devShell.contents = [dns-setup];
    }
    (lib.mkIf isDarwin {
      programs.supervisord.programs.dnsmasq = {
        command = "${pkgs.dnsmasq}/bin/dnsmasq --no-daemon --no-resolv --no-hosts --address=/${cfg.domainSuffix}/${cfg.address} --listen-address=${cfg.address} --port=${toString config.ports.dns}";
      };

      devShell.shellHooks = lib.mkOrder 780 ''
        ${dns-setup}/bin/dns-setup
      '';
    })
  ]);
}
