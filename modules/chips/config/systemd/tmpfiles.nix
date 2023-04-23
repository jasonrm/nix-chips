{
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; {
  # Copied from nixos/modules/system/boot/systemd/tmpfiles.nix
  options = {
    systemd.tmpfiles.rules = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["d /tmp 1777 root root 10d"];
      description = lib.mdDoc ''
        Rules for creation, deletion and cleaning of volatile and temporary files
        automatically. See
        {manpage}`tmpfiles.d(5)`
        for the exact format.
      '';
    };

    systemd.tmpfiles.packages = mkOption {
      type = types.listOf types.package;
      default = [];
      example = literalExpression "[ pkgs.lvm2 ]";
      apply = map getLib;
      description = lib.mdDoc ''
        List of packages containing {command}`systemd-tmpfiles` rules.

        All files ending in .conf found in
        {file}`«pkg»/lib/tmpfiles.d`
        will be included.
        If this folder does not exist or does not contain any files an error will be returned instead.

        If a {file}`lib` output is available, rules are searched there and only there.
        If there is no {file}`lib` output it will fall back to {file}`out`
        and if that does not exist either, the default output will be used.
      '';
    };
  };
}
