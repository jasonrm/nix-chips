{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep mapAttrsToList mkIf mkOption types;

  cfg = config.project.mutableFiles;

  mergeFile =
    pkgs.writers.writePython3 "chips-mutable-file-merge" {
      libraries = with pkgs.python3Packages; [pyyaml tomli-w];
    } ''
      import json
      import sys
      import tomllib
      from pathlib import Path

      import tomli_w
      import yaml


      def merge(base, overlay):
          if isinstance(base, dict) and isinstance(overlay, dict):
              merged = dict(base)
              for key, value in overlay.items():
                  merged[key] = merge(merged[key], value) if key in merged else value
              return merged
          return overlay


      format_name = sys.argv[1]
      dest_path = Path(sys.argv[2])
      source_path = Path(sys.argv[3])
      output_path = Path(sys.argv[4])


      def read_data(path):
          if not path.exists():
              return {}

          if format_name == "json":
              with path.open() as file:
                  return json.load(file)

          if format_name == "yaml":
              with path.open() as file:
                  return yaml.safe_load(file) or {}

          with path.open("rb") as file:
              return tomllib.load(file)


      def write_data(path, data):
          if format_name == "json":
              with path.open("w") as file:
                  json.dump(data, file, indent=2, sort_keys=True)
                  file.write("\n")
              return

          if format_name == "yaml":
              with path.open("w") as file:
                  yaml.safe_dump(data, file, sort_keys=True)
              return

          path.write_bytes(tomli_w.dumps(data).encode())


      write_data(output_path, merge(read_data(dest_path), read_data(source_path)))
    '';

  syncFile = pkgs.writeShellScript "chips-sync-mutable-file" ''
    set -o errexit
    set -o nounset
    set -o pipefail

    mutable_src="$1"
    mutable_dest="$2"
    merge_format="$3"
    mutable_dir="$(${pkgs.coreutils}/bin/dirname "$mutable_dest")"
    mutable_effective_src="$mutable_src"
    mutable_merged=""

    cleanup() {
      if [ -n "$mutable_merged" ]; then
        ${pkgs.coreutils}/bin/rm -f "$mutable_merged"
      fi
    }
    trap cleanup EXIT

    ${pkgs.coreutils}/bin/mkdir -p "$mutable_dir"

    if [ "$merge_format" != none ]; then
      mutable_merged="$(${pkgs.coreutils}/bin/mktemp)"
      ${mergeFile} "$merge_format" "$mutable_dest" "$mutable_src" "$mutable_merged"
      mutable_effective_src="$mutable_merged"
    fi

    if [ -f "$mutable_dest" ]; then
      if ${pkgs.diffutils}/bin/cmp -s "$mutable_dest" "$mutable_effective_src"; then
        echo "mutable file unchanged: $mutable_dest"
        exit 0
      fi

      echo "mutable file changed: $mutable_dest"
      ${pkgs.difftastic}/bin/difft "$mutable_dest" "$mutable_effective_src" || true
      hash="$(${pkgs.coreutils}/bin/sha256sum "$mutable_dest" | ${pkgs.coreutils}/bin/cut -c1-8)"
      ${pkgs.coreutils}/bin/mv "$mutable_dest" "$mutable_dest.$hash.bak"
    else
      echo "mutable file created: $mutable_dest"
    fi

    ${pkgs.coreutils}/bin/cp "$mutable_effective_src" "$mutable_dest"
    ${pkgs.coreutils}/bin/chmod u+rw "$mutable_dest"
  '';

  resolveSource = name: fileCfg:
    if fileCfg.source != null
    then fileCfg.source
    else pkgs.writeText (builtins.baseNameOf name) fileCfg.text;

  projectRoot =
    if config.dir.project == "/dev/null"
    then null
    else config.dir.project;

  validRelativePath = name:
    name
    != ""
    && !(lib.hasPrefix "/" name)
    && lib.all (part: part != "..") (lib.splitString "/" name);

  syncCommand = name: fileCfg:
    if !validRelativePath name
    then throw "project.mutableFiles.${name}: file name must be a relative path without '..' components"
    else if (fileCfg.source == null) == (fileCfg.text == null)
    then throw "project.mutableFiles.${name}: set exactly one of source or text"
    else let
      destination =
        if projectRoot == null
        then ''"$PWD"/${lib.escapeShellArg name}''
        else lib.escapeShellArg "${projectRoot}/${name}";
    in
      concatStringsSep " " [
        (lib.escapeShellArg syncFile)
        (lib.escapeShellArg (toString (resolveSource name fileCfg)))
        destination
        (lib.escapeShellArg fileCfg.merge)
      ];
in {
  options.project.mutableFiles = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        source = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Nix store path to copy into the project.";
        };

        text = mkOption {
          type = types.nullOr types.lines;
          default = null;
          description = "Text content to copy into the project.";
        };

        merge = mkOption {
          type = types.enum ["none" "json" "toml" "yaml"];
          default = "none";
          description = ''
            Merge strategy used before writing the file. Structured merge
            formats recursively overlay the Nix-managed source onto the
            existing file, preserving destination-only keys.
          '';
        };
      };
    });
    default = {};
    description = ''
      Mutable files copied into the project instead of symlinked to the Nix
      store. Changed files are diffed and backed up with a short hash suffix.
      Attribute names are paths relative to dir.project, or to the shell's
      entry directory when dir.project is unset.
    '';
  };

  config = mkIf (cfg != {}) {
    # Run after the usual generated-config hooks so a mutable declaration wins
    # if another module would otherwise install a store symlink at the same path.
    devShell.shellHooks = lib.mkOrder 1100 (
      concatStringsSep "\n" (mapAttrsToList syncCommand cfg)
    );
  };
}
