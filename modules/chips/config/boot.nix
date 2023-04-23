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
    };
  };
}
