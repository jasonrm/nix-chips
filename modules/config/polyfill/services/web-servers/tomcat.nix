{ lib, pkgs, config, ... }:
let
  cfg = config.services.tomcat;

  inherit (lib) generators mkForce;

  # mkValueString = value:
  #   if value == true then "yes"
  #   else if value == false then "no"
  #   else generators.mkValueStringDefault { } value;

  # tomcatConfig = pkgs.writeText "tomcat.conf" (generators.toKeyValue {
  #   listsAsDuplicateKeys = true;
  #   mkKeyValue = generators.mkKeyValueDefault { inherit mkValueString; } " ";
  # } cfg.settings);
in
{
  config = {
    services.tomcat = {
      baseDir = mkForce "${config.dir.lib}/tomcat";
    };

    systemd.services.tomcat.serviceConfig.ExecStart = mkForce "${pkgs.tomcat9}/bin/catalina.sh run";

    programs.supervisord.programs.tomcat = {
      environment = [
        "CATALINA_BASE=${cfg.baseDir}"
        "CATALINA_PID=${config.dir.run}/tomcat.pid"
        "JAVA_HOME=${cfg.jdk}"
        "JAVA_OPTS=\"${builtins.toString cfg.javaOpts}\""
        "CATALINA_OPTS=\"${builtins.toString cfg.catalinaOpts}\""
      ] ++ cfg.extraEnvironment;
    };
  };
}
