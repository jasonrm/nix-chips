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
        };
      };
      languages = {
        CSS = {formatter = {language_server = {name = "biome";};};};
        GraphQL = {formatter = {language_server = {name = "biome";};};};
        JSON = {formatter = {language_server = {name = "biome";};};};
        JSONC = {formatter = {language_server = {name = "biome";};};};
        JavaScript = {
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
          formatter = {language_server = {name = "biome";};};
        };
        TSX = {
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
          formatter = {language_server = {name = "biome";};};
        };
        TypeScript = {
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
