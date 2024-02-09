{
  system,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.lefthook;

  leftHookConfigFile = pkgs.writeText "lefthook.yml" (builtins.toJSON cfg.config);

  lefthookCommand = with types; {
    options = {
      glob = mkOption {
        type = nullOr str;
        default = null;
      };
      run = mkOption {
        type = str;
      };
    };
  };

  lefthookConfig = with types; {
    options = {
      commands = mkOption {
        type = attrsOf (submodule lefthookCommand);
        default = {};
      };
      parallel = mkOption {
        type = bool;
        default = true;
      };
    };
  };
in {
  options = {
    programs.lefthook = with types; {
      enable = mkEnableOption "lefthook support";
      config = mkOption {
        type = attrsOf (submodule lefthookConfig);
        default = {};
      };
    };
  };

  config = mkIf cfg.enable {
    programs.lefthook.config = {
      pre-commit = {
        commands = {
          alejandra = {
            glob = "*.nix";
            run = "${pkgs.alejandra}/bin/alejandra --quiet {staged_files} && git add {staged_files}";
          };
          jpegtran = {
            glob = "*.{jpg,jpeg}";
            run = "for $FILE in {staged_files}; do jpegtran -copy none -optimize -progressive -outfile $FILE $FILE; done && git add {staged_files}";
          };
          oxipng = {
            glob = "*.png";
            run = "${pkgs.oxipng}/bin/oxipng -o 3 -i 0 --strip safe {staged_files} && git add {staged_files}";
          };
          sort-json = {
            glob = "*.json";
            run = "for $FILE in {staged_files}; do jq -S . $FILE > $FILE.tmp && mv $FILE.tmp $FILE; done && git add {staged_files}";
          };
        };
        parallel = true;
      };
      pre-push = {
        commands = {};
        parallel = true;
      };
    };
    devShell = {
      contents = [
        pkgs.lefthook
      ];
      shellHooks = ''
        ln -sf ${leftHookConfigFile} lefthook.yml
        ${pkgs.lefthook}/bin/lefthook install
      '';
    };
  };
}
