{ system, pkgs, lib, config, ... }:
with lib;
let
  inherit (lib) mapAttrs types;
  inherit (pkgs.writers) writeBashBin;
  inherit (pkgs.stdenv) isDarwin;
  inherit (pkgs) symlinkJoin mkShell dockerTools;

  cfg = config.dockerImages;

  baseImage = dockerTools.buildImage {
    name = "baseContents";
    contents = cfg.baseContents;
  };

  preEntry = (pkgs.writeShellScriptBin "pre-entry" ''
    echo ensureExists: ${lib.concatStringsSep " " (map escapeShellArg config.dir.ensureExists)}
    ${pkgs.coreutils}/bin/mkdir -p ${lib.concatStringsSep " " (map escapeShellArg config.dir.ensureExists)}
    mkdir -p tmp/ && chmod 1777 tmp/
    exec $*
  '');

  dockerImageOption = with types; {
    options = {
      config = mkOption {
        type = attrs;
        default = { };
      };
      contents = mkOption {
        type = listOf package;
        default = [ ];
      };
      entrypoint = mkOption {
        type = listOf str;
        default = [ ];
      };
      command = mkOption {
        type = listOf str;
        default = [ ];
      };
      extraCommands = mkOption {
        type = listOf str;
        default = [ ];
      };
      environment = mkOption {
        type = listOf str;
        default = [ ];
      };
    };
  };
in
{
  imports = [
    # paths to other modules
  ];

  options = with types; {
    dockerImages = {
      baseContents = mkOption {
        type = listOf package;
        default = [ ];
      };
      images = mkOption {
        default = { };
        type = attrsOf (submodule dockerImageOption);
      };
    };

    outputs.legacyPackages.dockerImages = mkOption {
      type = attrsOf package;
    };
  };

  config = {
    outputs.legacyPackages.dockerImages = mapAttrs
      (k: v: (
        dockerTools.buildImage {
          name = k;
          fromImage = baseImage;
          extraCommands = lib.concatStringsSep "\n" v.extraCommands;
          inherit (v) contents;
          config = v.config // {
            # TODO: Support Entrypoint from v.config
            Entrypoint = ["${preEntry}/bin/pre-entry"];
          };
        }
      ))
      config.dockerImages.images;
  };
}
