{ lib, pkgs, config, ... }:
let
  inherit (lib) mkOption types concatStrings optional concatMapStringsSep replaceStrings escapeShellArg;
  cfg = config.services.tomcat;
  tomcat = cfg.package;

  tomcatExec = pkgs.writeShellScriptBin "tomcat-exec" ''
    mkdir -p \
      ${cfg.dataDir}/{conf,virtualhosts,logs,temp,lib,shared/lib,webapps,work}

    # Create a symlink to the bin directory of the tomcat component
    ln -sfn ${tomcat}/bin ${cfg.dataDir}/bin

    # Symlink the config files in the conf/ directory (except for catalina.properties and server.xml)
    for i in $(ls ${tomcat}/conf | grep -v catalina.properties | grep -v server.xml); do
      ln -sfn ${tomcat}/conf/$i ${cfg.dataDir}/conf/`basename $i`
    done

    # Create a modified catalina.properties file
    # Change all references from CATALINA_HOME to CATALINA_BASE and add support for shared libraries
    sed -e 's|''${catalina.home}|''${catalina.base}|g' \
      -e 's|shared.loader=|shared.loader=''${catalina.base}/shared/lib/*.jar|' \
      ${tomcat}/conf/catalina.properties > ${cfg.dataDir}/conf/catalina.properties

    ${if cfg.serverXml != "" then ''
      cp -f ${pkgs.writeTextDir "server.xml" cfg.serverXml}/* ${cfg.dataDir}/conf/
    '' else
      let
        hostElementForVirtualHost = virtualHost: ''
          <Host name="${virtualHost.name}" appBase="virtualhosts/${virtualHost.name}/webapps"
                unpackWARs="true" autoDeploy="true" xmlValidation="false" xmlNamespaceAware="false">
        '' + concatStrings (innerElementsForVirtualHost virtualHost) + ''
          </Host>
        '';
        innerElementsForVirtualHost = virtualHost:
          (map (alias: ''
            <Alias>${alias}</Alias>
          '') virtualHost.aliases);
        hostElementsString = concatMapStringsSep "\n" hostElementForVirtualHost cfg.virtualHosts;
        hostElementsSedString = replaceStrings ["\n"] ["\\\n"] hostElementsString;
      in ''
        # Create a modified server.xml which also includes all virtual hosts
        sed -e "/<Engine name=\"Catalina\" defaultHost=\"localhost\">/a\\"${escapeShellArg hostElementsSedString} \
              ${tomcat}/conf/server.xml > ${cfg.dataDir}/conf/server.xml
      ''
    }

    # Symlink all the given common libs files or paths into the lib/ directory
    for i in ${tomcat} ${toString cfg.commonLibs}; do
      if [ -f $i ]; then
        # If the given web application is a file, symlink it into the common/lib/ directory
        ln -sfn $i ${cfg.dataDir}/lib/`basename $i`
      elif [ -d $i ]; then
        # If the given web application is a directory, then iterate over the files
        # in the special purpose directories and symlink them into the tomcat tree

        for j in $i/lib/*; do
          ln -sfn $j ${cfg.dataDir}/lib/`basename $j`
        done
      fi
    done

    # Symlink all the given shared libs files or paths into the shared/lib/ directory
    for i in ${toString cfg.sharedLibs}; do
      if [ -f $i ]; then
        # If the given web application is a file, symlink it into the common/lib/ directory
        ln -sfn $i ${cfg.dataDir}/shared/lib/`basename $i`
      elif [ -d $i ]; then
        # If the given web application is a directory, then iterate over the files
        # in the special purpose directories and symlink them into the tomcat tree

        for j in $i/shared/lib/*; do
          ln -sfn $j ${cfg.dataDir}/shared/lib/`basename $j`
        done
      fi
    done

    # Symlink all the given web applications files or paths into the webapps/ directory
    for i in ${toString cfg.webapps}; do
      if [ -f $i ]; then
        # If the given web application is a file, symlink it into the webapps/ directory
        ln -sfn $i ${cfg.dataDir}/webapps/`basename $i`
      elif [ -d $i ]; then
        # If the given web application is a directory, then iterate over the files
        # in the special purpose directories and symlink them into the tomcat tree

        for j in $i/webapps/*; do
          ln -sfn $j ${cfg.dataDir}/webapps/`basename $j`
        done

        # Also symlink the configuration files if they are included
        if [ -d $i/conf/Catalina ]; then
          for j in $i/conf/Catalina/*; do
            mkdir -p ${cfg.dataDir}/conf/Catalina/localhost
            ln -sfn $j ${cfg.dataDir}/conf/Catalina/localhost/`basename $j`
          done
        fi
      fi
    done

    ${toString (map (virtualHost: ''
      # Create webapps directory for the virtual host
      mkdir -p ${cfg.dataDir}/virtualhosts/${virtualHost.name}/webapps

      # Symlink all the given web applications files or paths into the webapps/ directory
      # of this virtual host
      for i in "${if virtualHost ? webapps then toString virtualHost.webapps else ""}"; do
        if [ -f $i ]; then
          # If the given web application is a file, symlink it into the webapps/ directory
          ln -sfn $i ${cfg.dataDir}/virtualhosts/${virtualHost.name}/webapps/`basename $i`
        elif [ -d $i ]; then
          # If the given web application is a directory, then iterate over the files
          # in the special purpose directories and symlink them into the tomcat tree

          for j in $i/webapps/*; do
            ln -sfn $j ${cfg.dataDir}/virtualhosts/${virtualHost.name}/webapps/`basename $j`
          done

          # Also symlink the configuration files if they are included
          if [ -d $i/conf/Catalina ]; then
            for j in $i/conf/Catalina/*; do
              mkdir -p ${cfg.dataDir}/conf/Catalina/${virtualHost.name}
              ln -sfn $j ${cfg.dataDir}/conf/Catalina/${virtualHost.name}/`basename $j`
            done
          fi
        fi
      done
    '') cfg.virtualHosts)}

    exec ${pkgs.tomcat9}/bin/catalina.sh run
  '';
in
{
  options = with types; {
    services.tomcat = {
      enable = lib.mkEnableOption "enable tomcat";

      package = mkOption {
        type = package;
        default = pkgs.tomcat9;
      };

      jdk = mkOption {
        type = types.package;
        default = pkgs.jdk;
      };

      commonLibs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List containing JAR files or directories with JAR files which are libraries shared by the web applications and the servlet container";
      };

      sharedLibs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List containing JAR files or directories with JAR files which are libraries shared by the web applications";
      };

      runDir = mkOption {
        type = str;
        default = "${config.dir.run}/tomcat";
      };
      logDir = mkOption {
        type = str;
        default = "${config.dir.log}/tomcat";
      };
      dataDir = mkOption {
        type = str;
        default = "${config.dir.lib}/tomcat";
      };

      serverXml = mkOption {
        type = lines;
        default = "";
        description = "
          Verbatim server.xml configuration.
          This is mutually exclusive with the virtualHosts options.
        ";
      };

      javaOpts = mkOption {
        type = types.either (types.listOf types.str) types.str;
        default = "";
        description = "Parameters to pass to the Java Virtual Machine which spawns Apache Tomcat";
      };

      catalinaOpts = mkOption {
        type = types.either (types.listOf types.str) types.str;
        default = "";
        description = "Parameters to pass to the Java Virtual Machine which spawns the Catalina servlet container";
      };

      extraEnvironment = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "ENVIRONMENT=production" ];
        description = "Environment Variables to pass to the tomcat service";
      };

      webapps = mkOption {
        type = types.listOf types.path;
        default = [ tomcat.webapps ];
        defaultText = literalExpression "[ pkgs.tomcat85.webapps ]";
        description = "List containing WAR files or directories with WAR files which are web applications to be deployed on Tomcat";
      };

      virtualHosts = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "name of the virtualhost";
            };
            aliases = mkOption {
              type = types.listOf types.str;
              description = "aliases of the virtualhost";
              default = [];
            };
            webapps = mkOption {
              type = types.listOf types.path;
              description = ''
                List containing web application WAR files and/or directories containing
                web applications and configuration files for the virtual host.
              '';
              default = [];
            };
          };
        });
        default = [];
        description = "List consisting of a virtual host name and a list of web applications to deploy on each virtual host";
      };

      # host = mkOption {
      #   type = str;
      #   default = "0.0.0.0";
      # };
      # port = mkOption {
      #   type = int;
      #   default = config.ports.tomcat;
      # };
    };
  };

  config = lib.mkIf cfg.enable {
    dir.ensureExists = [
      cfg.runDir
      cfg.logDir
      cfg.dataDir
    ];
    shell.environment = [
      # "TOMCAT_HOST=${if (cfg.host == "0.0.0.0") then "127.0.0.1" else cfg.host}"
      # "TOMCAT_PORT=${toString cfg.port}"
    ];
    programs.supervisord.programs.tomcat = {
      command = "${tomcatExec}/bin/tomcat-exec";
      environment = [
        "CATALINA_BASE=${cfg.dataDir}"
        "CATALINA_PID=${config.dir.run}/tomcat.pid"
        "JAVA_HOME=${cfg.jdk}"
        "JAVA_OPTS=\"${builtins.toString cfg.javaOpts}\""
        "CATALINA_OPTS=\"${builtins.toString cfg.catalinaOpts}\""
      ] ++ cfg.extraEnvironment;
    };
  };
}
