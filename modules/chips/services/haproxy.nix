{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) concatMapStringsSep concatStringsSep mapAttrsToList mkIf mkMerge mkOption optionalString types;

  cfg = config.services.haproxy;
  legoCfg = config.programs.lego;
  pemFile = "${config.dir.data}/haproxy.pem";
  pemDirectory = "${config.dir.data}/haproxy-certs";
  tlsCertPath =
    if legoCfg.enable
    then cfg.pemDirectory
    else cfg.pemFile;

  fallbackDomain =
    if legoCfg.domains != []
    then builtins.head legoCfg.domains
    else config.project.domainSuffix;

  hasStructured =
    cfg.virtualHosts
    != {}
    || cfg.backends != {}
    || cfg.defaultBackend != null;

  acls = mapAttrsToList (
    name: vh: "  acl host_${name} hdr(host) -i ${vh.host}"
  ) (lib.filterAttrs (n: vh: vh.frontend == "https") cfg.virtualHosts);

  useBackends = mapAttrsToList (
    name: vh: "  use_backend ${vh.backend} if host_${name}"
  ) (lib.filterAttrs (n: vh: vh.frontend == "https") cfg.virtualHosts);

  renderBackend = name: be: ''
    backend ${name}
      mode ${be.mode}
    ${concatMapStringsSep "\n" (s: "  server ${s.name} ${s.address}") be.servers}
    ${optionalString (be.extraConfig != "") "  ${lib.replaceStrings ["\n"] ["\n  "] be.extraConfig}"}
  '';

  renderedBackends = concatStringsSep "\n" (mapAttrsToList renderBackend cfg.backends);

  generatedConfig = ''
    ${optionalString cfg.frontends.http.enable ''
      frontend http-in
        bind ${config.project.address}:${toString config.ports.http}
        http-request redirect scheme https code 301
    ''}

    ${optionalString cfg.frontends.https.enable ''
      frontend https-in
        bind ${config.project.address}:${toString config.ports.https} ssl crt ${tlsCertPath} alpn h2,http/1.1
        http-request set-header X-Forwarded-Proto https
        http-request set-header X-Forwarded-Host %[req.hdr(host)]
      ${concatStringsSep "\n" acls}
      ${concatStringsSep "\n" useBackends}
      ${optionalString (cfg.defaultBackend != null) "  default_backend ${cfg.defaultBackend}"}
    ''}

    ${renderedBackends}
  '';

  haproxyCfg = pkgs.writeText "haproxy.conf" ''
    global
      log stdout format raw local0 notice

    defaults
      mode http
      log global
      option httplog
      option dontlognull
      option forwardfor
      option http-server-close
      timeout connect 5s
      timeout client  1h
      timeout server  1h

    ${optionalString hasStructured generatedConfig}

    ${
      if cfg.config == null
      then ""
      else cfg.config
    }
  '';

  buildHaproxyPem = pkgs.writeShellScriptBin "build-haproxy-pem" ''
    set -euo pipefail

    pem=${lib.escapeShellArg legoCfg.pemFile}
    pem_dir=${lib.escapeShellArg legoCfg.pemDirectory}
    out=${lib.escapeShellArg cfg.pemFile}
    out_dir=${lib.escapeShellArg cfg.pemDirectory}
    existing_pem=0

    mkdir -p "$out_dir"
    for cert in "$out_dir"/*.pem; do
      [ -e "$cert" ] || break
      existing_pem=1
      break
    done

    if [ -s "$pem" ]; then
      umask 077
      cp "$pem" "$out"
      rm -f "$out_dir"/*.pem
      copied=0
      for cert in "$pem_dir"/*.pem; do
        [ -e "$cert" ] || break
        cp "$cert" "$out_dir"/
        copied=1
      done
      if [ "$copied" -eq 0 ]; then
        cp "$pem" "$out_dir/default.pem"
      fi
      echo "haproxy: lego PEM written to $out"
    elif [ ! -s "$out" ] && [ "$existing_pem" -eq 0 ]; then
      echo "haproxy: lego certs missing; generating self-signed fallback at $out and $out_dir/default.pem" >&2
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
      cp "$out" "$out_dir/default.pem"
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

    services.haproxy.pemDirectory = mkOption {
      type = types.str;
      default = pemDirectory;
      readOnly = true;
      description = "Directory containing certificate and key PEM files for HAProxy TLS binds.";
    };

    services.haproxy.frontends.http.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Generate http-in frontend redirecting plain HTTP to HTTPS.";
    };

    services.haproxy.frontends.https.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Generate the shared https-in frontend with TLS termination and host-based routing.";
    };

    services.haproxy.defaultBackend = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Backend used by https-in when no virtual host matches.";
    };

    services.haproxy.virtualHosts = mkOption {
      default = {};
      description = "Host-based routing rules attached to the shared https-in frontend.";
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          host = mkOption {
            type = types.str;
            default = name;
            description = "Value to match against the Host header (case-insensitive).";
          };
          backend = mkOption {
            type = types.str;
            description = "Name of the backend to route to.";
          };
          frontend = mkOption {
            type = types.enum ["https"];
            default = "https";
          };
        };
      }));
    };

    services.haproxy.backends = mkOption {
      default = {};
      description = "Named backends referenced by virtualHosts or defaultBackend.";
      type = types.attrsOf (types.submodule {
        options = {
          mode = mkOption {
            type = types.enum ["http" "tcp"];
            default = "http";
          };
          servers = mkOption {
            default = [];
            type = types.listOf (types.submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  default = "srv";
                };
                address = mkOption {
                  type = types.str;
                  description = "host:port the backend forwards traffic to.";
                };
              };
            });
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Raw lines appended to the backend block.";
          };
        };
      });
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
