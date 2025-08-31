{config, ...}: {
  config = {
    arcanum = {
      identity = "~/.ssh/id_ed25519";
      relativeRoot = ../../.;
    };

    arcanum.files.project-env = {
      source = "secrets/project.env.age";
      dest = "${config.dir.data}/.env.project";
    };

    programs.supervisord.enable = true;
    # services.mysql.enable = true;
    # programs.rust.enable = true;
  };
}
