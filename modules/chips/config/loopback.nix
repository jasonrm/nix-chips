{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.project;
  needsSetup = cfg.address != "127.0.0.1";
  isDarwin = pkgs.stdenv.isDarwin;

  setup-loopback = pkgs.writeShellScriptBin "setup-loopback" (
    if isDarwin
    then ''
      set -euo pipefail

      # Add loopback alias on macOS (requires sudo)
      if ifconfig lo0 | grep -q "inet ${cfg.address} "; then
        echo "Loopback alias ${cfg.address} already configured on lo0"
      else
        echo "Adding loopback alias ${cfg.address} to lo0..."
        sudo ifconfig lo0 alias ${cfg.address}
        echo "Done."
      fi
    ''
    else ''
      set -euo pipefail

      # Linux routes all of 127.0.0.0/8 natively
      echo "Loopback address ${cfg.address} is available (Linux handles 127.0.0.0/8 natively)"
    ''
  );

  check-loopback = pkgs.writeShellScriptBin "check-loopback" (
    if isDarwin
    then ''
      set -euo pipefail

      if ! ifconfig lo0 2>/dev/null | grep -q "inet ${cfg.address} "; then
        echo ""
        echo "WARNING: Loopback address ${cfg.address} is not configured on lo0."
        echo "Services will fail to bind. Run: setup-loopback"
        echo ""
      fi
    ''
    else ''
      set -euo pipefail

      # Linux routes all of 127.0.0.0/8 natively, nothing to check
    ''
  );

  check-dns = pkgs.writeShellScriptBin "check-dns" ''
    set -euo pipefail

    expected="${cfg.address}"
    domain="${cfg.domainSuffix}"
    failed=""

    echo "Checking DNS resolution for project domain: $domain"
    echo "Expected address: $expected"
    echo ""

    # Check root domain
    root_result=$(${pkgs.dig}/bin/dig +short "$domain" A 2>/dev/null | head -1) || root_result=""
    if [ "$root_result" = "$expected" ]; then
      echo "OK: $domain -> $root_result"
    else
      echo "FAIL: $domain -> ''${root_result:-<no result>} (expected $expected)"
      failed=1
    fi

    # Check wildcard via random subdomain
    probe="nix-chips-dns-check-$$-$RANDOM"
    wildcard_domain="$probe.$domain"
    wildcard_result=$(${pkgs.dig}/bin/dig +short "$wildcard_domain" A 2>/dev/null | head -1) || wildcard_result=""
    if [ "$wildcard_result" = "$expected" ]; then
      echo "OK: *.$domain -> $wildcard_result (tested $wildcard_domain)"
    else
      echo "FAIL: *.$domain -> ''${wildcard_result:-<no result>} (expected $expected, tested $wildcard_domain)"
      failed=1
    fi

    if [ -n "$failed" ]; then
      exit 1
    fi
  '';
in {
  config = lib.mkMerge [
    {
      devShell.contents = [check-dns];
    }
    (lib.mkIf needsSetup {
      devShell = {
        contents = [setup-loopback check-loopback];
        shellHooks = lib.mkBefore "${check-loopback}/bin/check-loopback";
      };
    })
  ];
}
