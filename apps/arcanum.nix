{pkgs, ...}: {
  type = "app";
  program = "${pkgs.arcanum}/bin/arcanum";
}
