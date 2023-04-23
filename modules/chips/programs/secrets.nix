{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  inherit (pkgs) writeShellScriptBin;

  cfg = config.secrets;

  secret = writeShellScriptBin "secret" ''
    set -o errexit
    set -o pipefail
    set -o nounset

    if [[ -z ''${1:-} || -z ''${2:-} ]]; then
      echo "Usage: $(basename $0) <edit|decrypt|encrypt> <encrypted-file>"
      exit 1
    fi

    AGE_SECRET_KEY_FILE=''${AGE_SECRET_KEY_FILE:-$HOME/.config/age/key.text}

    ENCRYPTED_FILE=$2
    DECRYPTED_FILE=''${ENCRYPTED_FILE%.age}
    RECIPIENTS=$(nix eval --json '.#secretRecipients' | jq -r "if .\"$ENCRYPTED_FILE\" then .\"$ENCRYPTED_FILE\" else [] end | join(\"\n\")")
    if [[ -z "$RECIPIENTS" ]]; then
      echo "No recipients found for $ENCRYPTED_FILE"
      exit 1
    fi

    IDENTITIES=""
    for identity in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$AGE_SECRET_KEY_FILE"; do
      if [[ -f "$identity" ]]; then
        IDENTITIES="$IDENTITIES --identity $identity"
      fi
    done


    ENCRYPT=()
    while IFS= read -r key
    do
        ENCRYPT+=(--recipient "$key")
    done <<< "$RECIPIENTS"

    if [[ $1 == 'edit' ]]; then
      if [[ -f "$ENCRYPTED_FILE" ]]; then
        ${pkgs.rage}/bin/rage --decrypt $IDENTITIES -o "$DECRYPTED_FILE" "$ENCRYPTED_FILE"
      else
        touch $DECRYPTED_FILE
      fi
      PRE_HASH=$(shasum -a 256 "$DECRYPTED_FILE")
      $EDITOR "$DECRYPTED_FILE"
      POST_HASH=$(shasum -a 256 "$DECRYPTED_FILE")
      if [[ "$PRE_HASH" != "$POST_HASH" ]]; then
        ${pkgs.rage}/bin/rage --encrypt --armor "''${ENCRYPT[@]}" -o "$ENCRYPTED_FILE" "$DECRYPTED_FILE"
        echo "Encrypted $ENCRYPTED_FILE"
      else
        echo "No changes made to $ENCRYPTED_FILE"
      fi
    elif [[ $1 == 'decrypt' ]]; then
        ${pkgs.rage}/bin/rage --decrypt $IDENTITIES -o "$DECRYPTED_FILE" "$ENCRYPTED_FILE"
        echo "Decrypted $DECRYPTED_FILE"
    elif [[ $1 == 'encrypt' ]]; then
        ${pkgs.rage}/bin/rage --encrypt --armor "''${ENCRYPT[@]}" -o "$ENCRYPTED_FILE" "$DECRYPTED_FILE"
        echo "Encrypted $ENCRYPTED_FILE"
    elif [[ $1 == 'rekey' ]]; then
        ${pkgs.rage}/bin/rage --decrypt $IDENTITIES -o "$DECRYPTED_FILE" "$ENCRYPTED_FILE"
        ${pkgs.rage}/bin/rage --encrypt --armor "''${ENCRYPT[@]}" -o "$ENCRYPTED_FILE" "$DECRYPTED_FILE"
        echo "Rekeyed $ENCRYPTED_FILE"
    fi
  '';
in {
  options = with lib.types; {};

  config = {
    #    chips.shell.contents = [
    #      secret
    #    ];

    outputs.packages.secret = secret;

    outputs.apps.secret = {
      program = "${secret}/bin/secret";
    };
  };
}
