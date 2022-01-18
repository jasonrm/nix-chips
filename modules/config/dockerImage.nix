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

  dockerImageOption = with types; {
    options = {
      config = mkOption {
        type = attrs;
        default = {};
      };
      contents = mkOption {
        type = listOf package;
        default = [ ];
      };
      extraCommands = mkOption {
        type = str;
        default = "";
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

    outputs.legacyPackages = mkOption { type = attrsOf package; };
  };

  config = {
    outputs.legacyPackages = mapAttrs (k: v: (
      dockerTools.buildImage {
          name = k;
          # fromImage = baseImage;
          inherit (v) extraCommands contents config;
        }
    )) config.dockerImages.images;
  };
}
