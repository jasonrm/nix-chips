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
      exit 0
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
    devShell = let
      filesWithDest = filterAttrs (n: secret: secret.dest != null) cfg.files;
    in {
      shellHooks = mkOrder 750 (
        concatStringsSep "\n" (
          mapAttrsToList (
            name: secret: "${decryptSecret} ${cfg.relativeRoot}/${secret.source} ${secret.dest}"
          )
          filesWithDest
        )
      );
    };
  };
}
