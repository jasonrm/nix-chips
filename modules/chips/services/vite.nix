{
  pkgs,
  lib,
  config,
  chips,
  ...
}:
with lib;
let
  inherit (chips.lib.traefik) hostRegexp;
  inherit (lib.lists) head drop;

  cfg = config.services.vite;

  schema = if config.programs.lego.enable then "https" else "http";

  moduleOptions =
    { name, ... }:
    let
      opts = cfg.instances.${name};
    in
    {
      options = with types; {
        enable = mkEnableOption (mdDoc "Enable this Vite instance");

        domains = mkOption {
          type = listOf str;
          default = [ "${name}.${config.project.domainSuffix}" ];
          description = mdDoc "List of domains for this instance.";
        };

        serverName = mkOption {
          type = str;
          default = head opts.domains;
          description = mdDoc "Server name for the virtual host.";
        };

        serverAliases = mkOption {
          type = listOf str;
          default = drop 1 opts.domains;
          description = mdDoc "Server aliases for the virtual host.";
        };

        virtualHost = mkOption {
          type = submodule (import "${pkgs.path}/nixos/modules/services/web-servers/nginx/vhost-options.nix");
          default = { };
          description = mdDoc ''
            Nginx configuration can be done by adapting {option}`services.nginx.virtualHosts`.
            See [](#opt-services.nginx.virtualHosts) for further information.
          '';
        };

        port = mkOption {
          type = int;
          default = 5173;
          description = "Port to run Vite dev server on.";
        };

        baseURI = mkOption {
          type = str;
          default = "${schema}://${builtins.head opts.domains}";
          description = mdDoc "Base URI for the Vite instance.";
        };
      };
    };
in
{
  options = with types; {
    services.vite = {
      instances = mkOption {
        type = attrsOf (submodule moduleOptions);
        default = { };
        description = mdDoc "Vite instances.";
      };
    };
  };

  config = mkMerge [
    {
      programs.supervisord = {
        enable = true;
        programs = mkMerge (
          mapAttrsToList (
            name: opts:
            if opts.enable then
              {
                "${name}" = {
                  autostart = true;
                  directory = config.dir.project;
                  stderr_logfile = "/dev/stderr";
                  command = "${pkgs.nodejs}/bin/node ./node_modules/vite/bin/vite.js dev --strictPort --host 127.0.0.1 --port ${toString opts.port}";
                };
              }
            else
              { }
          ) cfg.instances
        );
      };
    }
    {
      services.nginx = {
        virtualHosts = mkMerge (
          flatten (
            mapAttrsToList (
              name: opts:
              if opts.enable then
                [
                  {
                    "${head opts.domains}" = opts.virtualHost // {
                      serverName = head opts.domains;
                      serverAliases = drop 1 opts.domains;
                      locations = {
                        "/" = {
                          proxyPass = "http://127.0.0.1:${toString opts.port}";
                          proxyWebsockets = true;
                        };
                      };
                    } // (optionalAttrs config.programs.lego.enable {
                      onlySSL = true;
                      sslCertificate = config.programs.lego.certFile;
                      sslCertificateKey = config.programs.lego.keyFile;
                    });
                  }
                ]
              else
                [ ]
            ) cfg.instances
          )
        );
      };
    }
    {
      services.traefik = {
        routers = mkMerge (
          flatten (
            mapAttrsToList (
              name: opts:
              if opts.enable then
                [
                  {
                    "${name}" = {
                      service = "${name}";
                      rule = hostRegexp opts.domains;
                    };
                  }
                ]
              else
                [ ]
            ) cfg.instances
          )
        );
        services = mkMerge (
          flatten (
            mapAttrsToList (
              name: opts:
              if opts.enable then
                [
                  {
                    "${name}" = {
                      loadBalancer.servers = [ { url = "http://127.0.0.1:${toString opts.port}"; } ];
                    };
                  }
                ]
              else
                [ ]
            ) cfg.instances
          )
        );
      };
    }
    {
      devShell = {
        environment = flatten (
          mapAttrsToList (
            name: opts:
            let sanitizedName = builtins.replaceStrings ["-"] ["_"] name;
            in if opts.enable then
              [
                "VITE_BASE_URI_${lib.toUpper sanitizedName}=${opts.baseURI}"
                "RESOURCES_BASE_URI_${lib.toUpper sanitizedName}=${opts.baseURI}"
                "VITE_PORT_${lib.toUpper sanitizedName}=${toString opts.port}"
                "VITE_DOMAIN_${lib.toUpper sanitizedName}=${builtins.head opts.domains}"
              ]
            else
              [ ]
          ) cfg.instances
        );
      };
      services.php = {
        phpEnv = mkMerge (
          flatten (
            mapAttrsToList (
              name: opts:
              let sanitizedName = builtins.replaceStrings ["-"] ["_"] name;
              in if opts.enable then
                [
                  {
                    "VITE_BASE_URI_${lib.toUpper sanitizedName}" = opts.baseURI;
                    "RESOURCES_BASE_URI_${lib.toUpper sanitizedName}" = opts.baseURI;
                  }
                ]
              else
                [ ]
            ) cfg.instances
          )
        );
      };
    }
  ];
}
