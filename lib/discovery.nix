{lib}: let
  inherit (lib) filesystem hasSuffix removePrefix removeSuffix replaceStrings;
  inherit (filesystem) listFilesRecursive;

  onlyNix = path: hasSuffix ".nix" (baseNameOf path);
in {
  nixFilesIn = directory: builtins.filter onlyNix (listFilesRecursive directory);

  nixFileName = path: removeSuffix ".nix" (baseNameOf path);

  devShellName = devShellsDir: path: let
    dirStr = toString devShellsDir;
    pathStr = toString path;
    relative = removePrefix (dirStr + "/") pathStr;
    withoutNix = removeSuffix ".nix" relative;
    dotted = replaceStrings ["/"] ["."] withoutNix;
  in
    if hasSuffix ".default" dotted && dotted != "default"
    then removeSuffix ".default" dotted
    else dotted;
}
