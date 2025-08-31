{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.zed;

  zedSettingsJson = pkgs.writeText "zed-settings.json" (builtins.toJSON cfg.settings);
in {
  options = with lib.types; {
    programs.zed = {
      enable = mkEnableOption "Zed support";

      settings = mkOption {
        type = attrs;
        default = {};
        description = "Project level settings";
      };
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      shellHooks = ''
        mkdir -p .zed && ln -sf ${zedSettingsJson} .zed/settings.json
      '';
    };
  };
}
