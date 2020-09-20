{env-th ? (import <nixpkgs> {}).env-th}: with env-th; mkEnvironment rec {
  name = "python-env";
  definition = ./python-env.nix;
  shellHook = ''
    echo "${envError}"
    echo "${envError}" 1>&2
    exit 1
  '';
  envError = ''
    You have entered the python-env by running `env-reload`
    on a env-th.envs.python environment. Sorry, this isn't
    supported. Restart whatever you were doing with
    nix-shell.
    '';
  /* addEnvs = [env-th.env.python3]; */
  }
