{lib}: let
  inherit (lib) concatStringsSep flatten optionals assertMsg elemAt;
  withDomains = prefixes: domains: flatten (map (d: (map (p: ''`${p}.${d}`'') prefixes)) domains);
  hostRegexp = prefixes: domains: ''HostRegexp(${concatStringsSep ", " (withDomains prefixes domains)})'';
in {
  inherit withDomains;
  inherit hostRegexp;
}
