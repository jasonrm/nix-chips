{ system, pkgs, lib, config, ... }:
with lib;
let
  inherit (lib) mapAttrs types;
  inherit (pkgs.writers) writeBashBin;
  inherit (pkgs.stdenv) isDarwin;
  inherit (pkgs) symlinkJoin mkShell dockerTools;

  cfg = config.dockerImages;

  dockerImageOption = with lib.types; { name, ... }:
    let
      dockerImageOption = cfg.dockerImage.${name};
    in
    {
      options = {
        config = mkOption {
          type = attrs;
          default = {};
        };
        contents = mkOption {
          type = listOf package;
          default = [ ];
        };
        environment = mkOption {
          type = listOf str;
          default = [ ];
        };
      };

      config = {
        # environment = if lib.isAttrs envVars then () else envVars;
      };
    };
in
{
  imports = [
    # paths to other modules
  ];

  options = with lib.types; {
    dockerImages = mkOption {
      default = { };
      type = attrsOf (submodule dockerImageOption);
    };

    outputs.legacyPackages = mkOption { type = attrsOf package; };
  };

  config = {
    # shell.shellHooks = [
    #   ''
    #     export ${lib.concatStringsSep " " (map escapeShellArg cfg.environment)}
    # ];
    outputs.legacyPackages = mapAttrs (k: v: (
      dockerTools.buildImage {
          name = k;
          config = v.config;
        }
    )) config.dockerImages;
  };
}
