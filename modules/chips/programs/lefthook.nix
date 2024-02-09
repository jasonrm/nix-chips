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
      skip = mkOption {
        type = bool;
        default = false;
      };
    };
  };

  lefthookConfig = with types; {
    options = {
      commands = mkOption {
        type = nullOr (attrsOf (submodule lefthookCommand));
      };
      parallel = mkOption {
        type = nullOr bool;
      };
    };
  };

  lefthookGlobalConfig = with types; {
    options = {
      skip_output = mkOption {
        type = listOf str;
        default = [];
      };
      pre-commit = mkOption {
        type = submodule lefthookConfig;
        default = {};
      };
      pre-push = mkOption {
        type = submodule lefthookConfig;
        default = {};
      };
    };
  };
in {
  options = {
    programs.lefthook = with types; {
      enable = mkEnableOption "lefthook support";
      config = mkOption {
        type = submodule lefthookGlobalConfig;
        default = {};
      };
    };
  };

  config = mkIf cfg.enable {
    programs.lefthook.config = {
      skip_output = [
        "meta"
        "execution"
        "execution_out"
      ];
      pre-commit = {
        commands = {
          alejandra = {
            glob = mkDefault "*.nix";
            run = mkDefault "${pkgs.alejandra}/bin/alejandra --quiet {staged_files} && git add {staged_files}";
          };
          jpegtran = {
            glob = mkDefault "*.{jpg,jpeg}";
            run = mkDefault "for $FILE in {staged_files}; do jpegtran -copy none -optimize -progressive -outfile $FILE $FILE; done && git add {staged_files}";
          };
          oxipng = {
            glob = mkDefault "*.png";
            run = mkDefault "${pkgs.oxipng}/bin/oxipng -o 3 -i 0 --strip safe {staged_files} && git add {staged_files}";
          };
          sort-json = {
            glob = mkDefault "*.json";
            run = mkDefault "for $FILE in {staged_files}; do jq -S . $FILE > $FILE.tmp && mv $FILE.tmp $FILE; done && git add {staged_files}";
          };
          unresovled-conflicts = {
            run = mkDefault ''${pkgs.ripgrep}/bin/rg "(^[<>=]{5,})$" . ; if [[ $? -ne 1 ]]; then false; else true; fi'';
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
