{
  lib,
  pkgs,
  config,
  options,
  ...
}: let
  inherit
    (lib)
    escapeShellArg
    mkIf
    mkMerge
    optionalString
    mapAttrs'
    ;

  cfg = config.arcanum;

  mkDaemon = name: {
    source,
    dest,
    owner,
    group,
    permissions,
    directoryPermissions,
    makeDirectory,
    ...
  }: let
    storeSource = "${cfg.relativeRoot}/${source}";
    script = pkgs.writeScript "${name}-key-decrypt" ''
      #!/bin/sh
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
  in {
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
      ProgramArguments = [
        "${script}"
      ];
    };
  };
in {
  config = mkMerge [
    {
      launchd.daemons =
        mapAttrs' (name: info: {
          name = "${name}-key";
          value = mkDaemon name info;
        })
        cfg.files;
    }
    (mkIf (options ? home-manager) {
      home-manager.sharedModules = [../home-manager/arcanum.nix];
    })
  ];
}
