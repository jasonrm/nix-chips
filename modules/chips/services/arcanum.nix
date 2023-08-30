{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.arcanum;

  decryptSecret = pkgs.writeShellScript "decrypt" ''
    set -o errexit -o nounset -o pipefail
    if [ ! -f "$1" ]; then
      echo "Encrypted Secret Not Found: $1" >&2
      exit 1
    fi

    DECRYPTED_DIR=$(dirname "$2")
    if [[ ! -d "$DECRYPTED_DIR" ]]; then
      mkdir -p "$DECRYPTED_DIR"
    fi

    ${pkgs.rage}/bin/rage -d -i ${cfg.identity} -o "$2" "$1" \
      && chmod 600 "$2"
  '';
in {
  imports = [];

  options = {};

  config = {
    devShell = {
      shellHooks = concatStringsSep "\n" (mapAttrsToList (name: secret: "${decryptSecret} ${secret.source} ${secret.dest}") cfg.files);
    };
  };
}
