{ lib, pkgs, config, ... }:
let
  cfg = config.services.redis;

  inherit (lib) generators mkForce mkIf;

  mkValueString = value:
    if value == true then "yes"
    else if value == false then "no"
    else generators.mkValueStringDefault { } value;

  redisConfig = pkgs.writeText "redis.conf" (generators.toKeyValue {
    listsAsDuplicateKeys = true;
    mkKeyValue = generators.mkKeyValueDefault { inherit mkValueString; } " ";
  } cfg.settings);
in
{
  config = mkIf cfg.enable {
    services.redis.settings = {
      dir = mkForce "${config.dir.lib}/redis";
      supervised = mkForce false;
    };
    programs.supervisord.programs.redis.command = "${cfg.package}/bin/redis-server ${redisConfig}";
  };
}
