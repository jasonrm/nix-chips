{config, ...}: {
  config = {
    arcanum = {
      identity = "~/.ssh/id_ed25519";
      relativeRoot = ../../.; # Relative root directory for the repository in the nix store
    };

    arcanum.files.project-env = {
      source = "secrets/project.env.age";
      dest = "${config.dir.data}/.env.project";
      isEnvFile = true;
    };

    programs.supervisord.enable = true;
    # services.mysql.enable = true;
    # programs.rust.enable = true;
  };
}
