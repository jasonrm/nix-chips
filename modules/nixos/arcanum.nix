{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption escapeShellArg optionalString mapAttrs';

  cfg = config.arcanum;

  mkService = name: {
    source,
    dest,
    owner,
    group,
    permissions,
    directoryPermissions,
    makeDirectory,
    before,
    ...
  }: let
    storeSource = "${cfg.relativeRoot}/${source}";
  in {
    inherit before;
    description = "decrypt secret for ${name}";
    wantedBy = ["multi-user.target"];

    serviceConfig.Type = "oneshot";

    script = ''
      TARGET_DIR=$(dirname ${escapeShellArg dest})
      ${optionalString makeDirectory ''
        mkdir -p "$TARGET_DIR"
      ''}

      ${optionalString (directoryPermissions == null) ''
        chown '${owner}':'${group}' "$TARGET_DIR"
        chmod '0555' "$TARGET_DIR"
      ''}

      rm -rf ${escapeShellArg dest}

      ${pkgs.rage}/bin/rage -d -i ${escapeShellArg cfg.identity} -o ${escapeShellArg dest} ${escapeShellArg storeSource}

      chown '${owner}':'${group}' ${escapeShellArg dest}
      chmod '${permissions}' ${escapeShellArg dest}
    '';
  };
  #  arcanumOptions = ((import ../shared/arcanum.nix) {inherit lib pkgs config;}).options.arcanum;
in {
  imports = [
  ];

  options = {
    #    arcanum = mkOption {
    #      type = attrsOf (submodule arcanumOptions);
    #    };
  };

  config = {
    systemd.services = let
      units =
        mapAttrs' (name: info: {
          name = "${name}-key";
          value = mkService name info;
        })
        cfg.files;
    in
      units;
  };
}
