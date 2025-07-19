{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.programs.zed;

  zedSettingsJson = pkgs.writeText "zed-settings.json" (builtins.toJSON cfg.settings);
in
{
  options = with lib.types; {
    programs.zed = {
      enable = mkEnableOption "Zed support";

      settings = mkOption {
        type = attrs;
        default = { };
        description = "Project level settings";
      };
    };
  };

  config = {
    devShell = mkIf cfg.enable {
      nativeBuildInputs = [ toolchain-with-path ];
      contents = [ pkgs.libiconv ];
      environment = [
        "RUST_TOOLCHAIN_BIN=${cfg.toolchain}/bin"
        "RUST_STD_LIB=${cfg.standardLibraryOutput}"
      ];
      shellHooks = ''
        mkdir -p .zed && ln -sf ${zedSettingsJson} .zed/settings.json
      '';
    };
  };
}
