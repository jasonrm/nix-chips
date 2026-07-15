{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.project.profiles;
  metaCfg = config.project.metaProfiles;
  supervisord = "${config.programs.supervisord.output}/bin/supervisord";
in {
  options = with types; {
    project.profiles = mkOption {
      type = attrsOf (listOf str);
      default = {};
      description = ''
        Named groups of supervisord programs that start and stop together.
        Modules add their programs to a profile; members never autostart.
        `task dev` boots only the core (non-profile) services; profiles are
        started on demand via `task dev:<profile>`, the admin dashboard,
        or `supervisord ctl`.
      '';
    };
    project.metaProfiles = mkOption {
      type = attrsOf (listOf str);
      default = {};
      internal = true;
      description = ''
        Meta-profile name -> member programs, collected from
        `programs.supervisord.metaProfiles`. Tag programs where they are
        defined instead of setting this directly.
      '';
    };
    # Sibling of programs.supervisord.programs rather than an option on the
    # program submodule: program values transitively depend on
    # systemd.services (chips derives programs from them), and nginx's
    # service definition embeds the admin page that exports this data —
    # reading tags out of program values is an infinite recursion.
    programs.supervisord.metaProfiles = mkOption {
      type = attrsOf (listOf str);
      default = {};
      example = {webpack = ["ff-reports"];};
      description = ''
        Program name -> workflows (meta-profiles) it belongs to; declare
        next to the program definition. Meta-profiles overlap freely and
        do not create supervisord groups; each gets `task dev:<name>`
        tasks and a start/stop row on the admin page.
      '';
    };
  };

  config = mkMerge [
    {
      project.metaProfiles = zipAttrs (concatLists (mapAttrsToList
        (name: metas: map (meta: {${meta} = name;}) metas)
        config.programs.supervisord.metaProfiles));
    }
    (mkIf (cfg != {}) {
      programs.supervisord.groups = cfg;
      programs.supervisord.programs = genAttrs (concatLists (attrValues cfg)) (name: {
        autostart = mkForce false;
      });

      programs.taskfile.config.tasks =
        {
          "dev:status" = {
            desc = "Show status of all supervised programs";
            cmds = ["${supervisord} ctl status"];
          };
        }
        // listToAttrs (concatLists (mapAttrsToList (profile: members: [
            {
              name = "dev:${profile}";
              value = {
                desc = "Start ${profile} profile (${concatStringsSep ", " members})";
                cmds = ["${supervisord} ctl start ${concatStringsSep " " members}"];
              };
            }
            {
              name = "dev:${profile}:stop";
              value = {
                desc = "Stop ${profile} profile";
                cmds = ["${supervisord} ctl stop ${concatStringsSep " " members}"];
              };
            }
          ])
          (cfg // metaCfg)));
    })
  ];
}
