{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.bun;
in {
  options = with lib.types; {
    programs.biome = {
      enable = mkEnableOption "biome support";

      pkg = mkOption {
        type = package;
        default = pkgs.biome;
      };
    };
  };

  config = mkIf cfg.enable {
    programs.zed.settings = {
      lsp = {
        biome = {
          binary = {
            path = "${pkgs.biome}/bin/biome";
            arguments = ["lsp-proxy"];
          };
          settings = {
            require_config_file = true;
          };
        };
      };
      languages = {
        CSS = mkDefault {formatter = {language_server = {name = "biome";};};};
        GraphQL = mkDefault {formatter = {language_server = {name = "biome";};};};
        JSON = mkDefault {formatter = {language_server = {name = "biome";};};};
        JSONC = mkDefault {formatter = {language_server = {name = "biome";};};};
        JavaScript = mkDefault {
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
          formatter = {language_server = {name = "biome";};};
        };
        TSX = mkDefault {
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
          formatter = {language_server = {name = "biome";};};
        };
        TypeScript = mkDefault {
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
          formatter = {language_server = {name = "biome";};};
        };
      };
    };
  };
}
