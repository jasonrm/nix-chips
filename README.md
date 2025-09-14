nix-chips is a reproducible development environment for projects using thin wrappers around NixOS modules and custom NixOS-like modules providing configurable services and programs.

For example, Rust projects where Rust Rover or Zed are used, each should be auto-configured to use a specific rust/cargo toolchain. Similar for PHP, Java, etc.

[supervisord-go](https://github.com/ochinchina/supervisord) is used to run the services as it (usually) cleans up after running processes and many existing NixOS services that use systemd can be mapped to supervisord concepts. A custom [systemd-tmpfiles](https://github.com/jasonrm/systemd-tmpfiles) implementation is used to create temporary directories that would otherwise be created by systemd.

Rather than try to force nix flakes to be impure, per-user and per-machine nix modules are used. While this does "leak" information about the user's paths to git repositories, it also means that the configuration of other users of the project are inspectable. Good for reducing "works on my machine" issues, as well as making it easier to share configurations between users.

[arcanum](https://github.com/bitnixdev/arcanum) is a nix-chips specific utility used to encrypt and decrypt sensitive information using the [age](https://github.com/FiloSottile/age) library and per-machine SSH host keys.

## Nix Flake Template

```
nix flake new -t github:jasonrm/nix-chips project-dir
cd project-dir
git init
git add .
nix run .#init-dev-shell <github-username>
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
# layout php
# layout node
```

## Use

```shell
supervisord
# or, to see what will be started
supervisord-debug
```
