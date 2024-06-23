{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.lego;

  successHook = pkgs.writeShellScriptBin "success-hook" ''
    echo LEGO_CERT_PATH $LEGO_CERT_PATH
    cp "$LEGO_CERT_PATH" "${cfg.certFile}"
    echo LEGO_CERT_KEY_PATH $LEGO_CERT_KEY_PATH
    cp "$LEGO_CERT_KEY_PATH" "${cfg.keyFile}"
  '';

  keyName = builtins.replaceStrings ["*"] ["_"] (head cfg.domains);
  requestedDomains = pipe cfg.domains [
    (domains: sort builtins.lessThan domains)
    (domains: concatStringsSep "," domains)
  ];

  outDir = "${config.dir.data}/lego";
  globalOpts =
    [
      "--email ${cfg.email}"
      "--path ${outDir}"
    ]
    ++ (optionals cfg.acceptTermsOfService ["--accept-tos"])
    ++ (map (d: "--domains ${d}") cfg.domains)
    ++ cfg.additionalArgs;

  runOpts = escapeShellArgs (globalOpts ++ ["run" "--run-hook ${successHook}/bin/success-hook"]);
  renewOpts = escapeShellArgs (globalOpts ++ ["renew" "--renew-hook ${successHook}/bin/success-hook"]);

  # via: nixos/modules/security/acme.nix
  legoEnsureCerts = pkgs.writeScriptBin "lego-ensure-certs" ''
    set -o errexit -o nounset -o pipefail

    if [ ! -f "${cfg.envFile}" ]; then
      echo "Environment file not found: ${cfg.envFile}"
      exit 1
    fi

    set -o allexport
    source ${cfg.envFile}
    set +o allexport

    LEGO_ARGS=(${runOpts})
    if [ -e ${outDir}/certificates/${keyName}.crt ]; then
      REQUESTED_DOMAINS="${requestedDomains}"
      EXISTING_DOMAINS="$(${pkgs.openssl}/bin/openssl x509 -in ${outDir}/certificates/${keyName}.crt -noout -ext subjectAltName | tail -n1 | sed -e 's/ *DNS://g')"
      if [ "''${REQUESTED_DOMAINS}" == "''${EXISTING_DOMAINS}" ]; then
        LEGO_ARGS=(${renewOpts})
      fi
    fi
    ${pkgs.lego}/bin/lego ''${LEGO_ARGS[@]}
  '';
in {
  options = with types; {
    programs.lego = {
      enable = mkEnableOption "Enable Let’s Encrypt client.";

      acceptTermsOfService = mkEnableOption "By setting this flag to true you indicate that you accept the current Let's Encrypt terms of service.";

      pkg = mkOption {
        type = package;
        default = pkgs.lego;
      };

      email = mkOption {
        type = str;
      };

      domains = mkOption {
        type = listOf str;
        default = [
          "*.${config.project.domainSuffix}"
        ];
      };

      additionalArgs = mkOption {
        type = listOf str;
        default = [];
      };

      envFile = mkOption {
        type = nullOr path;
        default = null;
      };

      runHooks = mkOption {
        type = lines;
        default = [];
      };

      keyFile = mkOption {
        type = nullOr path;
        default = config.dir.data + "/lego.key";
        readOnly = true;
      };

      certFile = mkOption {
        type = nullOr path;
        default = config.dir.data + "/lego.crt";
        readOnly = true;
      };
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      contents = [
        legoEnsureCerts
      ];
      # Run after arcanum to ensure that the secrets are available
      shellHooks = optionalString (cfg.domains != [] && cfg.envFile != null) mkOrder 790 "${legoEnsureCerts}/bin/lego-ensure-certs";
    };

    #    outputs.apps.go = {
    #      program = "${cfg.pkg}/bin/go";
    #    };
  };
}
