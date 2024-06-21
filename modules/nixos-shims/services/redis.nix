{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
with lib; let
  cfg = config.services.redis;

  mkValueString = value:
    if value == true
    then "yes"
    else if value == false
    then "no"
    else generators.mkValueStringDefault {} value;

  redisConfig = settings:
    pkgs.writeText "redis.conf" (generators.toKeyValue {
        listsAsDuplicateKeys = true;
        mkKeyValue = generators.mkKeyValueDefault {inherit mkValueString;} " ";
      }
      settings);

  redisName = name: "redis" + optionalString (name != "") ("-" + name);
  enabledServers = filterAttrs (name: conf: conf.enable) config.services.redis.servers;
in {
  imports = [
    (modulesPath + "/services/databases/redis.nix")
  ];

  config = mkIf (enabledServers != {}) {
    systemd.services = mapAttrs' (name: conf: let
      newSettings = removeAttrs conf.settings ["dir" "unixsocket" "unixsocketperm"];
      in
      nameValuePair (redisName name) {
        serviceConfig = {
          ExecStart = mkForce "${cfg.package}/bin/${cfg.package.serverBin or "redis-server"} ${redisConfig newSettings} ${escapeShellArgs conf.extraParams}";
          ExecStartPre = mkForce "";
        };
      })
    enabledServers;
  };
}
