{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.httpServices;
in {
  options = with types; {
    services.httpServices = mkOption {
      default = {};
      description = ''
        One supervised HTTP process behind haproxy: each entry emits the
        matching programs.supervisord.programs.<name>, a haproxy backend
        on project.address:port, and a virtualHost routing host -> backend.
      '';
      type = attrsOf (submodule ({name, ...}: {
        options = {
          command = mkOption {
            type = str;
            description = "Command to supervise.";
          };
          port = mkOption {
            type = int;
            description = "Port the service listens on (bound on project.address).";
          };
          host = mkOption {
            type = str;
            default = "${name}.${config.project.domainSuffix}";
            description = "Hostname routed to this service. Defaults to <name>.<domainSuffix>.";
          };
          autostart = mkOption {
            type = bool;
            default = false;
          };
          directory = mkOption {
            type = nullOr str;
            default = null;
            description = "Working directory for the supervised process (null = supervisord default).";
          };
          environment = mkOption {
            type = listOf str;
            default = [];
          };
          envFiles = mkOption {
            type = listOf (oneOf [path str]);
            default = [];
          };
          backendExtraConfig = mkOption {
            type = lines;
            default = "";
            description = "Raw lines appended to the haproxy backend block (e.g. timeout tunnel 1h).";
          };
          programExtraConfig = mkOption {
            type = attrs;
            default = {};
            description = "Extra attributes merged into the generated supervisord program.";
          };
        };
      }));
    };
  };

  config = mkIf (cfg != {}) {
    programs.supervisord = {
      enable = true;
      programs =
        mapAttrs (
          name: svc:
            {
              inherit (svc) autostart command environment envFiles;
            }
            // optionalAttrs (svc.directory != null) {inherit (svc) directory;}
            // svc.programExtraConfig
        )
        cfg;
    };
    services.haproxy = {
      backends =
        mapAttrs (name: svc: {
          servers = [{address = "${config.project.address}:${toString svc.port}";}];
          extraConfig = svc.backendExtraConfig;
        })
        cfg;
      virtualHosts =
        mapAttrs (name: svc: {
          inherit (svc) host;
          backend = name;
        })
        cfg;
    };
  };
}
