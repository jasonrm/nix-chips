{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; let
  inherit (pkgs) path callPackage writeText;
  systemdTmpfiles = callPackage "${path}/nixos/modules/system/boot/systemd/tmpfiles.nix" {
    utils = callPackage "${path}/nixos/lib/utils.nix" {};
  };
  tmpFilesRules = writeText "tmpfiles.conf" (concatStringsSep "\n" config.systemd.tmpfiles.rules);
in {
  options = systemdTmpfiles.options;
  config = {
    devShell.shellHooks = ''
      while IFS= read -r line; do
          case "$line" in
              d*|D*)
                  dir_path=$(echo $line | cut -d' ' -f2)
                  if [[ "$dir_path" == "${config.dir.data}"*  ]]; then
                      mkdir -p "$dir_path"
                  else
                      "Not creating '$dir_path' as it is outside of the data directory."
                  fi
                  ;;
          esac
      done < "${tmpFilesRules}"
    '';
  };
}
