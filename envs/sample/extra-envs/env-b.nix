{envth}:
let pyenv = envth.envs.python38.addPackages (ps: [ps.numpy]); in
with envth.addEnvs [pyenv]; mkEnvironment
{ name = "env-b";
  definition = ./env-b.nix;
  varB = "varB set in env-b";
  addEnvs = [pyenv];
  envlib = {
    env-b-python = ''echo "${envs.python38.python}.../"
                     ls ${envs.python38.python}/lib/python3.8/site-packages'';
  };
}
