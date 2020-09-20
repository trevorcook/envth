let addPyTest   = ps: [ps.toolz]; in
{env-th}: with env-th;
mkEnvironment {
  name = "py-env-1";
  definition = ./py-env-1.nix;
  addEnvs = [ (env-th.envs.python-env.addPackages addPyTest) ];
}
