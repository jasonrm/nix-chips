
## Example Use

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    chips.url = "git+ssh://git@github.com/jasonrm/nix-chips.git";
    chips.inputs.nixpkgs.follows = "nixpkgs";
    chips.inputs.nixpkgs-staging.follows = "nixpkgs-staging";
  };

  outputs = { nixpkgs, chips, ... }: chips.useProfile ../../modules {
    config = with chips.lib; {
      dir.project = requireImpureEnv "PWD";
      dir.root = requireImpureEnv "CHIPS_ROOT";
      nodejs = {
        enable = true;
        pkg = pkgs.nodejs-14_x;
      };
      php = {
        enable = true;
        extensions = { enabled, all, ... }: with all; enabled ++ [
          pcov
        ];
      };
    };
  };
}

```
