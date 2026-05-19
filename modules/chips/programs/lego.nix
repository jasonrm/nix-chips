{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.lego;

  domains = pipe cfg.domains [
    (domains: sort builtins.lessThan domains)
    unique
  ];

  outDir = "${config.dir.data}/lego";
  certStoreDir = "${outDir}/per-domain";
  keyName = domain: builtins.replaceStrings ["*"] ["_"] domain;
  domainPlan = concatStringsSep "\n" (map (domain: "${domain}\t${keyName domain}") domains);

  commonOpts = escapeShellArgs (
    [
      "--email"
      cfg.email
      "--path"
      certStoreDir
    ]
    ++ (optionals cfg.acceptTermsOfService ["--accept-tos"])
    ++ cfg.additionalArgs
  );

  # via: nixos/modules/security/acme.nix
  legoEnsureCerts = pkgs.writeShellScriptBin "lego-ensure-certs" ''
        set -o errexit -o nounset -o pipefail

        ${optionalString (cfg.envFile != null) ''
      if [ ! -f "${cfg.envFile}" ]; then
        echo "Environment file not found: ${cfg.envFile}" >&2
        exit 0
      fi

      set -o allexport
      source ${cfg.envFile}
      set +o allexport
    ''}

        mkdir -p ${outDir} ${certStoreDir}

        # Serialize concurrent invocations (e.g. parallel task runs) so we
        # don't race ACME challenges and trip "authorization must be pending".
        exec 9>${outDir}/.lego.lock
        ${pkgs.flock}/bin/flock -x 9

        if [ "${toString (length domains)}" -eq 0 ]; then
          exit 0
        fi

        renew_days_for_domain() {
          local domain="$1"
          local hash

          if [ "${toString cfg.renewStaggerDays}" -eq 0 ]; then
            echo "${toString cfg.renewDays}"
            return 0
          fi

          hash="$(${pkgs.coreutils}/bin/printf '%s\n' "$domain" | ${pkgs.coreutils}/bin/cksum | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
          echo $(( ${toString cfg.renewDays} + (hash % (${toString cfg.renewStaggerDays} + 1)) ))
        }

        cert_covers_domain() {
          local crt="$1"
          local domain="$2"
          ${pkgs.openssl}/bin/openssl x509 -in "$crt" -noout -ext subjectAltName 2>/dev/null \
            | ${pkgs.gnugrep}/bin/grep -F "DNS:$domain" >/dev/null
        }

        ensure_domain_cert() {
          local domain="$1"
          local key_name="$2"
          local crt="${certStoreDir}/certificates/$key_name.crt"
          local renew_days
          local renew_seconds
          local action=run
          local -a lego_args

          renew_days="$(renew_days_for_domain "$domain")"

          if [ -s "$crt" ] && cert_covers_domain "$crt" "$domain"; then
            renew_seconds=$((renew_days * 86400))

            if ${pkgs.openssl}/bin/openssl x509 -checkend "$renew_seconds" -noout -in "$crt" >/dev/null 2>&1; then
              echo "lego: certificate for $domain is not due for renewal"
              return 0
            fi

            action=renew
          fi

          lego_args=(${commonOpts} --domains "$domain" "$action")
          if [ "$action" = renew ]; then
            lego_args+=(--days "$renew_days")
          fi

          if ! ${cfg.pkg}/bin/lego "''${lego_args[@]}"; then
            echo "lego: certificate $action failed for $domain; continuing without fresh cert" >&2
          fi
        }

        merge_certs() {
          local cert_file=${escapeShellArg cfg.certFile}
          local key_file=${escapeShellArg cfg.keyFile}
          local pem_file=${escapeShellArg cfg.pemFile}
          local tmp_crt
          local tmp_key
          local tmp_pem
          local missing=0
          local changed=0

          ${pkgs.coreutils}/bin/mkdir -p \
            "$(${pkgs.coreutils}/bin/dirname "$cert_file")" \
            "$(${pkgs.coreutils}/bin/dirname "$key_file")" \
            "$(${pkgs.coreutils}/bin/dirname "$pem_file")"

      tmp_crt="$(${pkgs.coreutils}/bin/mktemp "${outDir}/.lego.crt.XXXXXX")"
      tmp_key="$(${pkgs.coreutils}/bin/mktemp "${outDir}/.lego.key.XXXXXX")"
      tmp_pem="$(${pkgs.coreutils}/bin/mktemp "${outDir}/.lego.pem.XXXXXX")"

      while IFS=$'\t' read -r domain key_name; do
        local crt="${certStoreDir}/certificates/$key_name.crt"
            local key="${certStoreDir}/certificates/$key_name.key"

            if [ -s "$crt" ] && [ -s "$key" ]; then
              ${pkgs.coreutils}/bin/cat "$crt" >> "$tmp_crt"
              ${pkgs.coreutils}/bin/printf '\n' >> "$tmp_crt"
              ${pkgs.coreutils}/bin/cat "$key" >> "$tmp_key"
              ${pkgs.coreutils}/bin/printf '\n' >> "$tmp_key"
              ${pkgs.coreutils}/bin/cat "$crt" "$key" >> "$tmp_pem"
              ${pkgs.coreutils}/bin/printf '\n' >> "$tmp_pem"
            else
              echo "lego: missing certificate or key for $domain; leaving merged certificate unchanged" >&2
              missing=1
            fi
          done <<'LEGO_DOMAINS'
    ${domainPlan}
    LEGO_DOMAINS

      if [ "$missing" -ne 0 ]; then
        ${pkgs.coreutils}/bin/rm -f "$tmp_crt" "$tmp_key" "$tmp_pem"
        return 0
      fi

          if ! ${pkgs.diffutils}/bin/cmp -s "$tmp_crt" "$cert_file"; then
            ${pkgs.coreutils}/bin/install -m 0644 "$tmp_crt" "$cert_file"
            changed=1
          fi

          if ! ${pkgs.diffutils}/bin/cmp -s "$tmp_key" "$key_file"; then
            ${pkgs.coreutils}/bin/install -m 0600 "$tmp_key" "$key_file"
            changed=1
          fi

          if ! ${pkgs.diffutils}/bin/cmp -s "$tmp_pem" "$pem_file"; then
            ${pkgs.coreutils}/bin/install -m 0600 "$tmp_pem" "$pem_file"
            changed=1
          fi

      if [ "$changed" -ne 0 ]; then
        true
        ${cfg.runHooks}
      fi

      ${pkgs.coreutils}/bin/rm -f "$tmp_crt" "$tmp_key" "$tmp_pem"
    }

        while IFS=$'\t' read -r domain key_name; do
          ensure_domain_cert "$domain" "$key_name"
        done <<'LEGO_DOMAINS'
    ${domainPlan}
    LEGO_DOMAINS

        merge_certs
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

      email = mkOption {type = str;};

      domains = mkOption {
        type = listOf str;
        default = ["*.${config.project.domainSuffix}"];
      };

      additionalArgs = mkOption {
        type = listOf str;
        default = [];
      };

      renewDays = mkOption {
        type = ints.positive;
        default = 30;
        description = "Start renewing certificates this many days before expiry.";
      };

      renewStaggerDays = mkOption {
        type = ints.unsigned;
        default = 14;
        description = "Add a deterministic per-domain renewal offset of up to this many days.";
      };

      envFile = mkOption {
        type = nullOr path;
        default = null;
      };

      runHooks = mkOption {
        type = lines;
        default = "";
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

      pemFile = mkOption {
        type = nullOr path;
        default = config.dir.data + "/lego.pem";
        readOnly = true;
      };
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      contents = [legoEnsureCerts];
    };

    programs.taskfile = mkIf (cfg.enable && cfg.domains != []) {
      enable = mkDefault true;
      config.tasks = {
        "lego:renew" = {
          desc = "Renew Lego Certificates";
          cmds = ["${legoEnsureCerts}/bin/lego-ensure-certs"];
        };
        dev.deps = ["lego:renew"];
      };
    };

    #    outputs.apps.go = {
    #      program = "${cfg.pkg}/bin/go";
    #    };
  };
}
