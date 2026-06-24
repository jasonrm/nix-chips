{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkMerge types optional optionalString mapAttrsToList escapeShellArg;

  cfg = config.services.garage;

  toml = pkgs.formats.toml {};
  configFile = toml.generate "garage.toml" cfg.settings;

  garageBin = "${cfg.package}/bin/garage";

  # S3 connection details, shared between the dev shell and consumers (php).
  s3Endpoint = "http://${config.project.address}:${toString config.ports.garageS3}";
  s3Region = cfg.settings.s3_api.s3_region;

  # `garage` CLI wrapper that points at the generated config (and rpc_secret)
  # so interactive commands (status, layout, bucket, key, ...) talk to the
  # running dev server. Mirrors the wrapper from the upstream NixOS module.
  garageCli = pkgs.writeShellScriptBin "garage" ''
    set -a
    ${optionalString (cfg.environmentFile != null) ''
      [ -f ${escapeShellArg cfg.environmentFile} ] && . ${escapeShellArg cfg.environmentFile}
    ''}
    set +a
    exec ${garageBin} -c ${configFile} "$@"
  '';

  # Single-node bootstrap: assign a layout to this node and apply it. Garage
  # is unusable (no storage capacity) until a layout is applied at least once.
  garageInit = pkgs.writeShellScriptBin "garage-init" ''
    set -euo pipefail
    garage() { ${garageCli}/bin/garage "$@"; }
    if ! garage status | ${pkgs.gnugrep}/bin/grep -q "NO ROLE ASSIGNED"; then
      echo "garage: node already has a role assigned, nothing to do"
      exit 0
    fi
    nodeId="$(garage node id -q | ${pkgs.coreutils}/bin/cut -d@ -f1)"
    garage layout assign -z dc1 -c 1G "$nodeId"
    # apply at current version + 1 (a fresh cluster is at version 0)
    version="$(garage layout show | ${pkgs.gnugrep}/bin/grep -oiE 'version[: ]+[0-9]+' | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+' | head -n1)"
    garage layout apply --version "$((version + 1))"
  '';
in {
  options = {
    services.garage = with types; {
      enable = mkEnableOption "Garage Object Storage (S3 compatible)";

      package = mkOption {
        type = package;
        default = pkgs.garage_2;
        defaultText = "pkgs.garage_2";
        description = "Garage package to use.";
      };

      logLevel = mkOption {
        type = enum ["error" "warn" "info" "debug" "trace"];
        default = "info";
        description = "Garage log level (sets RUST_LOG=garage=<level>).";
      };

      extraEnvironment = mkOption {
        type = attrsOf str;
        default = {};
        example = {RUST_BACKTRACE = "1";};
        description = "Extra environment variables to pass to the Garage server.";
      };

      environmentFile = mkOption {
        type = nullOr path;
        default = null;
        description = "File containing environment variables to be passed to the Garage server.";
      };

      settings = mkOption {
        description = "Garage configuration, see <https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/>.";
        type = submodule {
          freeformType = toml.type;
          options = {
            metadata_dir = mkOption {
              type = str;
              default = "${config.dir.data}/garage/meta";
              description = "Metadata directory, put this on a fast disk if possible.";
            };
            data_dir = mkOption {
              type = either str (listOf attrs);
              default = "${config.dir.data}/garage/data";
              description = "Directory in which Garage stores object data blocks.";
            };
          };
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      # Single-node dev defaults. Everything is mkDefault so a project can
      # override any of it via `services.garage.settings`.
      services.garage.settings = {
        replication_factor = mkDefault 1;
        # Non-secret, deterministic dev value (64 hex chars). Override for
        # anything that leaves localhost.
        rpc_secret = mkDefault "1799bccfd7411eddcf9ebd316bc1f5287ad12a68094e1c6ac6abde7e6feae1ec";
        rpc_bind_addr = mkDefault "${config.project.address}:${toString config.ports.garageRpc}";
        rpc_public_addr = mkDefault "${config.project.address}:${toString config.ports.garageRpc}";

        s3_api = {
          s3_region = mkDefault "garage";
          api_bind_addr = mkDefault "${config.project.address}:${toString config.ports.garageS3}";
          root_domain = mkDefault ".s3.garage.${config.project.domainSuffix}";
        };

        s3_web = {
          bind_addr = mkDefault "${config.project.address}:${toString config.ports.garageWeb}";
          root_domain = mkDefault ".web.garage.${config.project.domainSuffix}";
          index = mkDefault "index.html";
        };

        admin = {
          api_bind_addr = mkDefault "${config.project.address}:${toString config.ports.garageAdmin}";
          admin_token = mkDefault "garage-dev-admin-token";
        };
      };

      # Garage will not create the parent of the metadata/data dirs.
      dir.ensureExists =
        [cfg.settings.metadata_dir]
        ++ optional (lib.isString cfg.settings.data_dir) cfg.settings.data_dir;

      devShell.contents = [garageCli garageInit];

      devShell.environment = [
        "AWS_ENDPOINT_URL=${s3Endpoint}"
        "AWS_DEFAULT_REGION=${s3Region}"
      ];

      # Also expose the endpoint to PHP workers. phpfpm runs with clear_env=yes
      # and gets its env only from env[...] lines, so devShell.environment alone
      # would not reach PHP. Setting services.php.phpEnv is safe even when php is
      # unused (the option exists and is only consumed by enabled instances).
      services.php.phpEnv = {
        AWS_ENDPOINT_URL = s3Endpoint;
        AWS_DEFAULT_REGION = s3Region;
      };

      programs.supervisord.programs.garage = {
        command = "${garageBin} -c ${configFile} server";
        environment =
          ["RUST_LOG=garage=${cfg.logLevel}"]
          ++ mapAttrsToList (n: v: "${n}=${v}") cfg.extraEnvironment;
        envFiles = optional (cfg.environmentFile != null) cfg.environmentFile;
      };

      programs.taskfile.config.tasks.garage-init = {
        desc = "Assign and apply a single-node Garage layout (run once after first start)";
        cmds = ["${garageInit}/bin/garage-init"];
      };

      services.traefik = {
        routers.garage = {
          entryPoints = ["http"];
          service = "garage";
          rule = "HostRegexp(`{subdomain:.+}.s3.garage.${config.project.domainSuffix}`) || Host(`s3.garage.${config.project.domainSuffix}`)";
        };
        services.garage.loadBalancer.servers = [
          {url = "http://${config.project.address}:${toString config.ports.garageS3}";}
        ];
      };

      services.haproxy.virtualHosts.garage = {
        host = "s3.garage.${config.project.domainSuffix}";
        backend = "garage";
      };
      services.haproxy.backends.garage.servers = [
        {
          name = "garage";
          address = "${config.project.address}:${toString config.ports.garageS3}";
        }
      ];
    })
  ];
}
