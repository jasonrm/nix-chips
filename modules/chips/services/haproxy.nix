{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkIf mkMerge mkOption optionalString types;

  cfg = config.services.haproxy;
  legoCfg = config.programs.lego;
  pemFile = "${config.dir.data}/haproxy.pem";

  fallbackDomain =
    if legoCfg.domains != []
    then builtins.head legoCfg.domains
    else config.project.domainSuffix;

  haproxyCfg = pkgs.writeText "haproxy.conf" ''
    global
      log stdout format raw local0 info

    ${cfg.config}
  '';

  buildHaproxyPem = pkgs.writeShellScriptBin "build-haproxy-pem" ''
    set -euo pipefail

    crt=${lib.escapeShellArg legoCfg.certFile}
    key=${lib.escapeShellArg legoCfg.keyFile}
    out=${lib.escapeShellArg cfg.pemFile}

    if [ -s "$crt" ] && [ -s "$key" ]; then
      umask 077
      cat "$crt" "$key" > "$out"
      echo "haproxy: combined PEM written to $out"
    elif [ ! -s "$out" ]; then
      echo "haproxy: lego certs missing; generating self-signed fallback at $out" >&2
      umask 077
      tmp_key="$(${pkgs.coreutils}/bin/mktemp)"
      tmp_crt="$(${pkgs.coreutils}/bin/mktemp)"
      trap 'rm -f "$tmp_crt" "$tmp_key"' EXIT
      ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
        -subj "/CN=${fallbackDomain}" \
        -addext "subjectAltName=DNS:${fallbackDomain}" \
        -keyout "$tmp_key" \
        -out "$tmp_crt" 2>/dev/null
      cat "$tmp_crt" "$tmp_key" > "$out"
    fi
  '';

  haproxyExec = pkgs.writeShellScriptBin "haproxy-exec" ''
    ${optionalString legoCfg.enable "${buildHaproxyPem}/bin/build-haproxy-pem"}
    exec ${pkgs.haproxy}/sbin/haproxy -W -f ${haproxyCfg}
  '';

  haproxy-debug = pkgs.writeShellScriptBin "haproxy-debug" ''
    cat ${haproxyCfg}
  '';
in {
  imports = [];

  options = {
    services.haproxy.pemFile = mkOption {
      type = types.str;
      default = pemFile;
      readOnly = true;
      description = "Combined certificate and key PEM file for HAProxy TLS binds.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.supervisord.programs.haproxy = {
        command =
          if pkgs.stdenv.isDarwin
          then "sudo -E ${haproxyExec}/bin/haproxy-exec"
          else "${haproxyExec}/bin/haproxy-exec";
      };
      devShell = {
        contents = [haproxy-debug];
      };
    }
    (mkIf legoCfg.enable {
      programs.lego.runHooks = ''
        ${buildHaproxyPem}/bin/build-haproxy-pem
      '';
      devShell.contents = [buildHaproxyPem];
    })
  ]);
}
