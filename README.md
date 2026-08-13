nix-chips is a reproducible development environment for projects using thin wrappers around NixOS modules and custom NixOS-like modules providing configurable services and programs.

For example, Rust projects where Rust Rover or Zed are used, each should be auto-configured to use a specific rust/cargo toolchain. Similar for PHP, Java, etc.

[supervisord-go](https://github.com/ochinchina/supervisord) is used to run the services as it (usually) cleans up after running processes and many existing NixOS services that use systemd can be mapped to supervisord concepts. A custom [systemd-tmpfiles](https://github.com/jasonrm/systemd-tmpfiles) implementation is used to create temporary directories that would otherwise be created by systemd.

Rather than try to force nix flakes to be impure, per-user and per-machine nix modules are used. While this does "leak" information about the user's paths to git repositories, it also means that the configuration of other users of the project are inspectable. Good for reducing "works on my machine" issues, as well as making it easier to share configurations between users.

[arcanum](https://github.com/bitnixdev/arcanum) provides optional encrypted-secret support for nix-chips development shells using the [age](https://github.com/FiloSottile/age) library and per-machine SSH host keys.

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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-staging.url = "github:jasonrm/nixpkgs-staging";
    nixpkgs-staging.inputs.nixpkgs.follows = "nixpkgs";

    chips.url = "github:jasonrm/nix-chips";
    chips.inputs.nixpkgs.follows = "nixpkgs";
    chips.inputs.nixpkgs-staging.follows = "nixpkgs-staging";

    arcanum.url = "github:bitnixdev/arcanum";
    arcanum.inputs.nixpkgs.follows = "nixpkgs";
    arcanum.inputs.nixpkgs-staging.follows = "nixpkgs-staging";
    arcanum.inputs.chips.follows = "chips";
  };

  outputs = inputs @ {chips, arcanum, ...}:
    chips.lib.mkFlake {
      inherit inputs;
      sources = {
        devShells = ./nix/devShells;
        packages = ./nix/packages;
        nixosModules = ./nix/nixosModules;
        dockerImages = ./nix/dockerImages;
      };
      modules.chips = [arcanum.chipsModules.default];
      nixpkgs.overlays = [arcanum.overlays.default];
    };
}
```

### `.envrc`

```
if ! has nix_direnv_version || ! nix_direnv_version 3.1.2; then
  source_url "https://raw.githubusercontent.com/nix-community/nix-direnv/3.1.2/direnvrc" "sha256-Di03ad3a0ueGi6CGrfhrQzyGdQIg9APXIPCAMNQgWYM="
fi
source_env_if_exists .envrc.private
use flake ".#${USER}${PROFILE:+.${PROFILE}}"
# layout php
# layout node
```

`.envrc` is committed to the repository. Use `.envrc.private` for local overrides.

## Mutable project files

Use `project.mutableFiles` for repository-local configuration that an application must be able to modify. Unlike a Nix store symlink, each file is copied into the project. Existing files are diffed and backed up as `<name>.<hash>.bak` before replacement.

```nix
{pkgs, ...}: let
  json = pkgs.formats.json {};
in {
  project.mutableFiles = {
    ".zed/settings.json" = {
      source = json.generate "zed-settings.json" {
        format_on_save = "on";
      };
      merge = "json";
    };

    ".toolrc".text = ''
      managed=true
    '';
  };
}
```

The `json`, `toml`, and `yaml` merge modes recursively overlay the Nix-managed source onto the existing file, preserving keys that exist only in the local file. The default merge mode is `none`. Paths are relative to `dir.project`, or to the directory where the shell is entered when `dir.project` is unset.

## Use

```shell
task dev
# or, to see what will be started
supervisord-debug
# or, to renew certificates without starting services
task lego-renew
```

## Docs

```shell
# generate docs/public/data and start Vite
task docs-dev

# generate docs/public/data and build docs/dist
task docs-build
```
