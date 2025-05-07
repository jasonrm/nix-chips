{ pkgs, lib }:
let
  inherit (pkgs) symlinkJoin writeShellScriptBin;
  inherit (lib) mapAttrsToList;
in
{
  # Takes an attribute set and converts into shell scripts to act as "global aliases"
  # Ex.
  # aliasToPackage {
  #   str = "${gcc}/bin/strings $@";
  #   hms = "home-manager switch;
  # }
  aliasToPackage =
    alias:
    symlinkJoin {
      name = "alias";
      paths = (mapAttrsToList (name: value: writeShellScriptBin name value) alias);
    };
}
