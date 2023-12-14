{ config, ...}: {
  config = {
    arcanum.files.project-env = {
      source = "secrets/project.env.age";
      dest = "${config.dir.data}/.env.project";
    };

    programs.supervisord.enable = true;
    # services.mysql.enable = true;
    # programs.rust.enable = true;
  };
}
