{pkgs}: let
  inherit (pkgs) lib;
  evaluated = lib.evalModules {
    specialArgs = {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
    };
    modules = [
      ../modules/chips/programs/taskfile.nix
      {
        options.devShell = {
          contents = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
          };
          shellHooks = lib.mkOption {
            type = lib.types.lines;
            default = "";
          };
        };
        config.programs.taskfile = {
          enable = true;
          config.tasks = {
            prepare.cmd = "printf 'prepare\\n'";
            example = {
              aliases = ["alias"];
              deps = ["prepare"];
              cmds = lib.mkForce ["printf 'body\\n'"];
            };
            aggregate.deps = ["example"];
            cached = {
              status = ["true"];
              cmds = ["exit 99"];
            };
            failure.cmd = "exit 7";
          };
        };
      }
    ];
  };
in
  pkgs.runCommand "taskfile-status-test" {
    nativeBuildInputs = [pkgs.go-task pkgs.nodejs pkgs.unixtools.script];
  } ''
    ${evaluated.config.devShell.shellHooks}
    export TASK_BIN=${pkgs.go-task}/bin/task
    export TASKFILE="$PWD/Taskfile.yml"
    node --test ${./taskfile.test.mjs}
    touch "$out"
  ''
