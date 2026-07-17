{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.project.admin;

  adminConfig = pkgs.writeText "admin-config.json" (builtins.toJSON {
    inherit (cfg) title;
    domain = cfg.host;
    profiles = config.project.profiles;
    metaProfiles = config.project.metaProfiles;
    links =
      [
        {
          name = "Supervisord";
          url = "https://supervisord.${config.project.domainSuffix}";
        }
      ]
      ++ cfg.links;
  });

  adminSite = pkgs.runCommand "admin-dashboard-site" {} ''
    mkdir -p $out
    cp ${./admin-dashboard/index.html} $out/index.html
    cp ${adminConfig} $out/config.json
  '';
in {
  options = with types; {
    project.admin = {
      enable = mkOption {
        type = bool;
        default = true;
        description = "Admin dashboard for supervised services at the bare project domain.";
      };
      host = mkOption {
        type = str;
        default = config.project.domainSuffix;
        description = "Hostname the dashboard is served on.";
      };
      title = mkOption {
        type = str;
        default =
          if config.project.name != ""
          then config.project.name
          else config.project.domainSuffix;
        defaultText = "project.name, or project.domainSuffix when unset";
        description = "Page title shown in the dashboard header.";
      };
      port = mkOption {
        type = int;
        default = 8182;
        description = "Local nginx port backing the dashboard.";
      };
      links = mkOption {
        type = listOf (submodule {
          options = {
            name = mkOption {type = str;};
            url = mkOption {type = str;};
          };
        });
        default = [];
        description = "Custom header links, shown after the built-in Supervisord link.";
      };
    };
  };

  config = mkIf cfg.enable {
    # Supervisord's HTTP API same-origin under the dashboard host. The API
    # rule must precede the page rule so /program/... never hits nginx.
    services.haproxy.frontends.https.extraConfig = ''
      acl admin_host hdr(host) -i ${cfg.host}
      acl admin_api path /RPC2
      acl admin_api path_beg /program/ /supervisor/
      use_backend supervisord if admin_host admin_api
      use_backend admin if admin_host
    '';
    services.haproxy.backends.admin.servers = [
      {address = "${config.project.address}:${toString cfg.port}";}
    ];

    services.nginx = {
      enable = true;
      virtualHosts.admin = {
        serverName = cfg.host;
        listen = [
          {
            addr = config.project.address;
            port = cfg.port;
          }
        ];
        root = adminSite;
        locations."/".extraConfig = ''
          try_files $uri /index.html;
        '';
      };
    };
  };
}
