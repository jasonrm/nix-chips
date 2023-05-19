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
    copyToRoot = cfg.baseContents;
  };

  preEntry = image: (pkgs.writeShellScriptBin "pre-entry" ''
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
          nobody:!:1::::::
          ${user}:!:::::::
        ''
      )
      (
        writeTextDir "etc/passwd" ''
          root:x:0:0::/root:${runtimeShell}
          nobody:x:65534:65534:Unprivileged account (don't use!):/var/empty:/run/current-system/sw/bin/nologin
          ${user}:x:${toString uid}:${toString gid}::/home/${user}:
        ''
      )
      (
        writeTextDir "etc/group" ''
          root:x:0:
          nogroup:x:65534:
          ${user}:x:${toString gid}:
        ''
      )
      (
        writeTextDir "etc/gshadow" ''
          root:x::
          nobody:!:1::::::
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

      output = mkOption {
        type = attrsOf package;
        readOnly = true;
      };
    };
  };

  config = {
    dockerImages.output =
      mapAttrs
      (k: image: (
        dockerTools.buildLayeredImage {
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
