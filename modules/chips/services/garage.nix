{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkMerge types optional optionalString mapAttrsToList concatStringsSep concatMapStringsSep escapeShellArg filter head;

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

  # Declarative bucket provisioning, applied idempotently by `garage-init` after
  # the layout. Garage exposes no CLI for CORS, so CORS rules are pushed through
  # the S3 PutBucketCors API using the bucket's own key.
  awsConfig = pkgs.writeText "garage-aws-config" ''
    [default]
    s3 =
        addressing_style = path
  '';

  # PutBucketCors is a bucket-admin operation, so CORS is applied with an owner key.
  corsKeyOf = bucket: let
    owners = filter (key: key.owner) bucket.keys;
  in
    if owners == []
    then null
    else head owners;

  corsConfigFile = name: bucket:
    pkgs.writeText "garage-cors-${name}.json" (builtins.toJSON {
      CORSRules = [
        {
          AllowedOrigins = bucket.cors.allowedOrigins;
          AllowedMethods = bucket.cors.allowedMethods;
          AllowedHeaders = bucket.cors.allowedHeaders;
          ExposeHeaders = bucket.cors.exposeHeaders;
          MaxAgeSeconds = bucket.cors.maxAgeSeconds;
        }
      ];
    });

  grantCommands = bucket:
    concatMapStringsSep "\n" (key: ''
      garage key import --yes -n ${escapeShellArg key.name} ${escapeShellArg key.id} ${escapeShellArg key.secret} 2>/dev/null \
        || echo "garage: key ${key.id} already imported"
      garage bucket allow ${optionalString key.read "--read "}${optionalString key.write "--write "}${optionalString key.owner "--owner "}${escapeShellArg bucket.name} --key ${escapeShellArg key.id}
    '')
    bucket.keys;

  corsCommand = name: bucket:
    if bucket.cors == null
    then ""
    else if corsKeyOf bucket == null
    then throw "services.garage.buckets.${name}.cors requires a key with owner = true (PutBucketCors needs owner permission)."
    else let
      key = corsKeyOf bucket;
    in ''
      echo "garage: applying CORS rules to bucket ${bucket.name}"
      AWS_ACCESS_KEY_ID=${escapeShellArg key.id} \
      AWS_SECRET_ACCESS_KEY=${escapeShellArg key.secret} \
      AWS_DEFAULT_REGION=${escapeShellArg s3Region} \
      AWS_CONFIG_FILE=${awsConfig} \
      AWS_EC2_METADATA_DISABLED=true \
        ${pkgs.awscli2}/bin/aws --endpoint-url ${s3Endpoint} s3api put-bucket-cors \
          --bucket ${escapeShellArg bucket.name} \
          --cors-configuration file://${corsConfigFile name bucket}
    '';

  bucketCommands = name: bucket: ''
    garage bucket create ${escapeShellArg bucket.name} 2>/dev/null \
      || echo "garage: bucket ${bucket.name} already exists"
    ${grantCommands bucket}
    ${optionalString bucket.website "garage bucket website --allow ${escapeShellArg bucket.name}"}
    ${corsCommand name bucket}
  '';

  bucketsInit = pkgs.writeShellScriptBin "garage-buckets-init" ''
    set -euo pipefail
    garage() { ${garageCli}/bin/garage "$@"; }
    ${concatStringsSep "\n" (mapAttrsToList bucketCommands cfg.buckets)}
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

      s3PublicHost = mkOption {
        type = str;
        default = "s3.${config.project.domainSuffix}";
        description = ''
          Public hostname the S3 API is fronted at (haproxy/traefik). A single
          label under the project domain so it is covered by the wildcard dns +
          cert; buckets are addressed path-style (host/bucket/key).
        '';
      };

      s3PublicEndpoint = mkOption {
        type = str;
        default = "https://${cfg.s3PublicHost}";
        defaultText = "https://\${config.services.garage.s3PublicHost}";
        description = "Public HTTPS endpoint for the S3 API, for browser/presigned-URL uploads.";
      };

      buckets = mkOption {
        default = {};
        description = "Buckets to provision on `garage-init`: create, grant keys, expose as a website, apply CORS.";
        type = attrsOf (submodule ({name, ...}: {
          options = {
            name = mkOption {
              type = str;
              default = name;
              description = "Bucket name (defaults to the attribute name).";
            };
            website = mkOption {
              type = bool;
              default = false;
              description = "Expose the bucket for anonymous reads via the web endpoint.";
            };
            keys = mkOption {
              default = [];
              description = "S3 keys to import and grant on this bucket.";
              type = listOf (submodule {
                options = {
                  id = mkOption {
                    type = str;
                    description = "Access key id (garage format: 'GK' + 24 hex).";
                  };
                  secret = mkOption {
                    type = str;
                    description = "Secret key (garage format: 64 hex).";
                  };
                  name = mkOption {
                    type = str;
                    default = "dev";
                    description = "Human-readable key name in garage.";
                  };
                  read = mkOption {
                    type = bool;
                    default = true;
                  };
                  write = mkOption {
                    type = bool;
                    default = true;
                  };
                  owner = mkOption {
                    type = bool;
                    default = false;
                  };
                };
              });
            };
            cors = mkOption {
              default = null;
              description = "CORS rule applied to the bucket via S3 PutBucketCors. Requires at least one key.";
              type = nullOr (submodule {
                options = {
                  allowedOrigins = mkOption {
                    type = listOf str;
                    description = "Origins allowed to call the bucket from a browser.";
                  };
                  allowedMethods = mkOption {
                    type = listOf str;
                    default = ["GET" "PUT" "HEAD"];
                  };
                  allowedHeaders = mkOption {
                    type = listOf str;
                    default = ["*"];
                  };
                  exposeHeaders = mkOption {
                    type = listOf str;
                    default = [];
                  };
                  maxAgeSeconds = mkOption {
                    type = int;
                    default = 3600;
                  };
                };
              });
            };
          };
        }));
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
        desc = "Provision dev object storage: apply the single-node layout, then create buckets/keys/website/CORS";
        cmds =
          ["${garageInit}/bin/garage-init"]
          ++ optional (cfg.buckets != {}) "${bucketsInit}/bin/garage-buckets-init";
      };

      services.traefik = {
        routers.garage = {
          entryPoints = ["http"];
          service = "garage";
          rule = "Host(`${cfg.s3PublicHost}`)";
        };
        services.garage.loadBalancer.servers = [
          {url = "http://${config.project.address}:${toString config.ports.garageS3}";}
        ];
      };

      services.haproxy.virtualHosts.garage = {
        host = cfg.s3PublicHost;
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
