{env-th}:
let pyenv = env-th.envs.python38.addPackages (ps: [ps.numpy]); in
with env-th.addEnvs [pyenv]; mkEnvironment
{ name = "env-b";
  definition = ./env-b.nix;
  varB = "varB set in env-b";
  addEnvs = [pyenv];
  lib = {
    env-b-python = ''echo "${envs.python38.python}.../"
                     ls ${envs.python38.python}/lib/python3.8/site-packages'';
  };
}
