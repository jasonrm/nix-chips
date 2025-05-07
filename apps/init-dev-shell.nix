{ pkgs, ... }:
let
  template = pkgs.writeText "template.nix" ''
    {
      config,
      pkgs,
      lib,
      ...
    }: {
      imports = [
        ./default.nix
      ];

      config = {
        dir.project = "$PWD";

        arcanum.defaultRecipients = [
    $PUBLIC_SSH_KEY
        ];
      };
    }
  '';

  init-dev-shell = pkgs.writeScriptBin "init-dev-shell" ''
    set -o errexit -o nounset -o pipefail

    if [ $# -ne 1 ]; then
      FILENAME=$(basename $0)
      echo "Usage: $FILENAME <github-username>" >&2
      exit 1
    fi
    GITHUB_USERNAME=$1

    if [ -f ~/.ssh/id_rsa.pub ]; then
      cat ~/.ssh/id_rsa.pub \
        | cut -d" " -f1-2 \
        | sed 's/^/      "/;s/$/"/' \
      > chips_ssh_keys.tmp
    fi

    if [ -f ~/.ssh/id_ed25519.pub ]; then
      cat ~/.ssh/id_ed25519.pub \
        | cut -d" " -f1-2 \
        | sed 's/^/      "/;s/$/"/' \
      > chips_ssh_keys.tmp
    fi

    ${pkgs.curl}/bin/curl -s https://github.com/$GITHUB_USERNAME.keys \
      | grep -E "(ssh-ed25519|ssh-rsa)" \
      | sed 's/^/      "/;s/$/"/' \
    > chips_ssh_keys.tmp

    export PUBLIC_SSH_KEY=$(cat chips_ssh_keys.tmp | sort | uniq)
    rm chips_ssh_keys.tmp

    mkdir -p $PWD/nix/devShells
    ${pkgs.gettext}/bin/envsubst < ${template} > $PWD/nix/devShells/$USER-$(hostname -s).nix
    ${pkgs.git}/bin/git add $PWD/nix/devShells/$USER-$(hostname -s).nix
  '';
in
{
  type = "app";
  program = "${init-dev-shell}/bin/init-dev-shell";
}
