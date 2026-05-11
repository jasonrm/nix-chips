{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.zed;

  jsonFormat = pkgs.formats.json {};
  zedSettingsJson = jsonFormat.generate "zed-settings.json" cfg.settings;
in {
  options = with lib.types; {
    programs.zed = {
      enable = mkEnableOption "Zed support";

      settings = mkOption {
        type = jsonFormat.type;
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
