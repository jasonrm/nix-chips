{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.programs.jujutsu;

  format = pkgs.formats.toml { };
  settingsFile = format.generate "config.toml" cfg.settings;
in
{
  options = with lib.types; {
    programs.jujutsu = {
      enable = mkEnableOption "Jujutsu support";

      settings = mkOption {
        type = attrs;
        default = {
          "$schema" = "https://jj-vcs.github.io/jj/latest/config-schema.json";

          revset-aliases = {
            "trunk()" = "master@origin";
          };
        };
        description = "Project level settings";
      };

      enableFormatting = mkOption {
        type = bool;
        default = true;
        description = "Enable formatting fix tools";
      };
    };
  };

  config = mkIf cfg.enable {
    programs.jujutsu.settings.fix.tools = {
      "format-nix" = {
        command = [
          "${pkgs.nixfmt-rfc-style}/bin/nixfmt"
          "--strict"
          "--filename=$path"
        ];
        patterns = [ "glob:'**/*.nix'" ];
      };

      "format-json" = {
        command = [
          "${pkgs.jq}/bin/jq"
          "--indent"
          "2"
          "."
        ];
        patterns = [ "glob:'**/*.json'" ];
      };
    };

    devShell = {
      contents = [ pkgs.jujutsu ];
      shellHooks = ''
        if [ -d .jj/repo ]; then
          mkdir -p .jj/repo/conf.d
          ln -sf ${settingsFile} .jj/repo/config.toml
        fi
      '';
    };
  };
}
