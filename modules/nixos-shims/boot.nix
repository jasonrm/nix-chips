{
  pkgs,
  lib,
  ...
}:
with lib; {
  options = with types; {
    boot = {
      kernel = mkOption {
        type = str;
        default = "linux";
      };
      kernelParams = mkOption {
        type = listOf str;
        default = [];
      };
      kernelModules = mkOption {
        type = listOf str;
        default = [];
      };
      kernelPackages = mkOption {
        type = attrs;
        default = {
          kernel = {
            version = "1";
          };
        };
      };
    };
  };
}
