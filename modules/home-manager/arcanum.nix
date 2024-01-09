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
    if [ ! -f ${cfg.identity} ]; then
      echo "Missing identity file: ${cfg.identity}" >&2
      exit 0
    fi

    if [ ! -f "$1" ]; then
      echo "Encrypted Secret Not Found: $1" >&2
      exit 0
    fi

    echo "Decrypting: $1 -> $2"
    DECRYPTED_DIR=$(dirname "$2")
    if [[ ! -d "$DECRYPTED_DIR" ]]; then
      mkdir -p "$DECRYPTED_DIR"
    fi

    ${pkgs.rage}/bin/rage -d -i ${cfg.identity} -o "$2" "$1" \
      && chmod 600 "$2"
  '';

  filesWithDest = filterAttrs (n: secret: secret.dest != null) cfg.files;
in {
  imports = [];

  options = {};

  config = {
    home.activation = {
      arcanum = lib.hm.dag.entryAfter ["writeBoundary"] (concatStringsSep "\n" (mapAttrsToList (name: secret: "${decryptSecret} ${cfg.relativeRoot}/${secret.source} ${secret.dest}") filesWithDest));
    };
  };
}
