## Templated Setup

```
git init

nix flake new -t github:jasonrm/nix-chips .

cat ./nix/devShells/user-hostname.nix \
    | python3 -c 'import os,sys;[sys.stdout.write(os.path.expandvars(l)) for l in sys.stdin]' \
    > ./nix/devShells/$(whoami)-$(hostname -s).nix

git add .

nix-direnv-reload
direnv allow
```

```shell
# setup secrets
arcanum edit secrets/project.env.age
```

## Manual Setup
### `flake.nix`
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";

    chips.url = "github:jasonrm/nix-chips";
    chips.inputs.nixpkgs.follows = "nixpkgs";
    chips.inputs.nixpkgs-staging.follows = "nixpkgs-staging";
  };

  outputs = {
    self,
    nixpkgs,
    chips,
    ...
  }:
    chips.lib.use {
      devShellsDir = ./nix/devShells;
      packagesDir = ./nix/packages;
      nixosModulesDir = ./nix/nixosModules;
      dockerImagesDir = ./nix/dockerImages;
    };
}
```

### `.envrc`
```
nix_direnv_manual_reload
use flake .#${USER}-$(hostname -s)
dotenv_if_exists .env.devshell
dotenv_if_exists .env.secrets
layout php
layout node
```

## Use

```shell
supervisord
# or, to see what will be started
supervisord-debug
```
