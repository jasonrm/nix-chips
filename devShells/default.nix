{...}: {
  config = {
    programs.nodejs = {
      enable = true;
      packageManager = "pnpm";
    };

    programs.jujutsu.enable = true;
  };
}
