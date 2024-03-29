{envth}:
 let pyenv = envth.envs.python38.addPackages (ps: [ps.toolz]); in
  # Add a version of python38 with the "toolz" package, and "./env-b.nix"
  # to the environments in `envth` and bring into scope.
with envth.addEnvs [pyenv ./env-b.nix];
mkEnvironment
{ name = "env-a";
  definition = ./env-a.nix;
  pyenv = pyenv.python;
  varA = "varA set in env-a";
  imports = [ envs.env-b ];
  env-addEnvs = [ envs.python38 # export modified python env, so that when
                            # an environment imports env-a, "toolz" will be
                            # added to the python package.
              envs.env-b    # Likewise, bring env-b, into scope.
              ];
  varB-refA  = envs.env-b.varB;
  envlib = {
    env-a-f = '' echo "env-a envlib" '';
    # Both env-a-python and env-b-pyton should report the same site packages.
    env-a-python = ''echo "${envs.python38.python}.../"
                     ls ${envs.python38.python}/lib/python3.8/site-packages'';
  };
}
