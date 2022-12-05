{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  inherit (lib) mapAttrs types;
  inherit (pkgs.writers) writeBashBin;
  inherit (pkgs.stdenv) isDarwin;
  inherit (pkgs) symlinkJoin mkShell dockerTools;

  cfg = config.dockerImages;

  baseImage = dockerTools.buildImage {
    name = "baseContents";
    contents = cfg.baseContents;
  };

  preEntry = image: (pkgs.writeShellScriptBin "pre-entry" ''
    echo preEntry: ensureExists
    ${pkgs.coreutils}/bin/mkdir -p ${lib.concatStringsSep " " (map escapeShellArg config.dir.ensureExists)}

    echo preEntry: entryCommands
    ${lib.concatStringsSep "\n" image.entryCommands}

    echo preEntry: tmp
    mkdir -p /tmp/ && chmod 1777 /tmp/

    echo preEntry: done
    exec $*
  '');

  nonRootShadowSetup = {
    user,
    uid,
    gid ? uid,
  }:
    with pkgs; [
      (
        writeTextDir "etc/shadow" ''
          root:!x:::::::
          ${user}:!:::::::
        ''
      )
      (
        writeTextDir "etc/passwd" ''
          root:x:0:0::/root:${runtimeShell}
          ${user}:x:${toString uid}:${toString gid}::/home/${user}:
        ''
      )
      (
        writeTextDir "etc/group" ''
          root:x:0:
          ${user}:x:${toString gid}:
        ''
      )
      (
        writeTextDir "etc/gshadow" ''
          root:x::
          ${user}:x::
        ''
      )
    ];

  dockerImageOption = with types; {
    options = {
      config = mkOption {
        type = attrs;
        default = {};
      };
      contents = mkOption {
        type = listOf package;
        default = [];
      };
      entryCommands = mkOption {
        type = listOf str;
        default = [];
      };
      command = mkOption {
        type = listOf str;
        default = [];
      };
      extraCommands = mkOption {
        type = listOf str;
        default = [];
      };
      environment = mkOption {
        type = listOf str;
        default = [
          "SSL_CERT_FILE=${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt"
        ];
      };
    };
  };
in {
  imports = [
    # paths to other modules
  ];

  options = with types; {
    dockerImages = {
      baseContents = mkOption {
        type = listOf package;
        default = [];
      };
      images = mkOption {
        default = {};
        type = attrsOf (submodule dockerImageOption);
      };
    };

    outputs.legacyPackages.dockerImages = mkOption {
      type = attrsOf package;
    };
  };

  config = {
    outputs.legacyPackages.dockerImages =
      mapAttrs
      (k: image: (
        dockerTools.buildImage {
          name = k;
          fromImage = baseImage;
          extraCommands = lib.concatStringsSep "\n" image.extraCommands;
          contents = image.contents;
          # WIP for users
          # (nonRootShadowSetup { user = "sshd"; uid = 999; });
          config =
            image.config
            // {
              # TODO: Support Entrypoint from v.config
              Entrypoint = ["${preEntry image}/bin/pre-entry"];
            };
        }
      ))
      config.dockerImages.images;
  };
}
