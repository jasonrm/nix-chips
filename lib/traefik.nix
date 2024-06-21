{lib}: let
  inherit (lib) concatStringsSep flatten optionals assertMsg elemAt;
  withDomains = prefixes: domains: flatten (map (d: (map (p: ''HostRegexp(`${p}.${d}`)'') prefixes)) domains);
  hostRegexp = prefixes: domains: concatStringsSep "||" (withDomains prefixes domains);
in {
  inherit withDomains;
  inherit hostRegexp;
}
